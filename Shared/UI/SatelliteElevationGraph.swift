//
//  SatelliteElevationGraph.swift
//  SatelliteForcast
//
//  Created by Ben Lu on 6/2/21.
//

import BTree
import CombineRex
import SwiftUI
import SatelliteKit
import SatelliteForcastCore
import CoreLocation
import CombineRextensions

struct SatelliteElevationGraphConfigs: Equatable {
    var timeGridLineInterval: TimeInterval
    var elevationGridLineInterval: Double
    var minimumHorizonalResolution: CGFloat

    static var preset: SatelliteElevationGraphConfigs {
        return SatelliteElevationGraphConfigs(
            timeGridLineInterval: 30 * 60,
            elevationGridLineInterval: 30,
            minimumHorizonalResolution: 3 / 60
        )
    }
}

enum SatelliteElevationGraphAction {
}

class SatelliteElevationGraphState: Equatable {
    static func == (lhs: SatelliteElevationGraphState, rhs: SatelliteElevationGraphState) -> Bool {
        return lhs.snapshots == rhs.snapshots && lhs.dateRange == rhs.dateRange && lhs.elevationGridLineInterval == rhs.elevationGridLineInterval
    }

    private static func snapshotPoint(_ snapshot: SatelliteSnapshot, xPercent: CGFloat, rect: CGRect) -> CGPoint {
        let x = rect.width * xPercent
        let y = CGFloat(snapshot.position.elev + 90) / 180 * -rect.height + rect.height
        return CGPoint(x: x, y: y)
    }

    private static var satelliteElevationCache: (Int, CGPath)?

    private static func satelliteElevationPathFunc(snapshots: Map<Date, SatelliteSnapshot>, snapshotsHash: Int) -> (CGRect) -> CGPath {
        return { rect in
            let path = CGMutablePath()
            if snapshots.isEmpty {
                return path
            }
            var hasher = Hasher()
            hasher.combine(snapshotsHash)
            hasher.combine(rect.origin.x)
            hasher.combine(rect.origin.y)
            hasher.combine(rect.size.width)
            hasher.combine(rect.size.height)
            let hashValue = hasher.finalize()
            if let cache = satelliteElevationCache, cache.0 == hashValue {
                return cache.1
            }

            for (i, (_, snapshot)) in snapshots.enumerated() {
                let xPercent = CGFloat(i) / CGFloat(snapshots.count)
                if i == 0 {
                    path.move(to: snapshotPoint(snapshot, xPercent: xPercent, rect: rect))
                } else {
                    path.addLine(to: snapshotPoint(snapshot, xPercent: xPercent, rect: rect))
                }
            }

            satelliteElevationCache = (hashValue, path)
            return path
        }
    }

    private static var unilluminatedPathsCache: (Int, CGPath)?

    private static func unilluminatedPathsFunc(
        snapshotsSplitByIllumination: [[(Int, SatelliteSnapshot)]],
        snapshotsHash: Int,
        totalCount: Int
    ) -> (CGRect) -> CGPath {
        return { rect in
            let path = CGMutablePath()
            if snapshotsSplitByIllumination.isEmpty {
                return path
            }
            var hasher = Hasher()
            hasher.combine(snapshotsHash)
            hasher.combine(rect.origin.x)
            hasher.combine(rect.origin.y)
            hasher.combine(rect.size.width)
            hasher.combine(rect.size.height)
            let hashValue = hasher.finalize()

            if let cache = unilluminatedPathsCache, cache.0 == hashValue {
                return cache.1
            }

            snapshotsSplitByIllumination
                .filter { !($0.first?.1.isIlluminated ?? true) }
                .forEach { snapshotGroup in
                    for (i, s) in snapshotGroup.enumerated() {
                        let (globalIndex, snapshot) = s
                        let xPercent = CGFloat(globalIndex) / CGFloat(totalCount)
                        if i == 0 {
                            path.move(to: snapshotPoint(snapshot, xPercent: xPercent, rect: rect))
                        } else {
                            path.addLine(to: snapshotPoint(snapshot, xPercent: xPercent, rect: rect))
                        }
                    }
                }

            unilluminatedPathsCache = (hashValue, path)
            return path
        }
    }

    // Generated data source
    fileprivate let satelliteElevationPath: (CGRect) -> CGPath
    fileprivate let unilluminatedPaths: (CGRect) -> CGPath
    fileprivate let xPercentDatePair: [(Double, Date, Int)]
    fileprivate let contentRect: (CGRect) -> CGRect

    // Copied properties
    fileprivate let snapshots: Map<Date, SatelliteSnapshot>
    /// Date range for display.
    fileprivate let dateRange: Range<Date>
    fileprivate let elevationGridLineInterval: Double

    static var empty: SatelliteElevationGraphState {
        .init(
            satelliteElevationPath: { _ in CGMutablePath() },
            unilluminatedPaths: { _ in CGMutablePath() },
            xPercentDatePair: [],
            contentRect: { $0 },
            snapshots: Map<Date, SatelliteSnapshot>(),
            dateRange: Date().advanced(by: -60 * 60 * 2)..<Date().advanced(by: 60 * 60 * 22),
            elevationGridLineInterval: 30
        )
    }

    init(
        satelliteElevationPath: @escaping (CGRect) -> CGPath,
        unilluminatedPaths: @escaping (CGRect) -> CGPath,
        xPercentDatePair: [(Double, Date, Int)],
        contentRect: @escaping (CGRect) -> CGRect,
        snapshots: Map<Date, SatelliteSnapshot>,
        dateRange: Range<Date>,
        elevationGridLineInterval: Double
    ) {
        self.satelliteElevationPath = satelliteElevationPath
        self.unilluminatedPaths = unilluminatedPaths
        self.xPercentDatePair = xPercentDatePair
        self.contentRect = contentRect
        self.snapshots = snapshots
        self.dateRange = dateRange
        self.elevationGridLineInterval = elevationGridLineInterval
    }

    static func project(state: Store.StateType) -> SatelliteElevationGraphState {
        let snapshots = state.currentSatelliteSnapshots
        let snapshotsHash: Int = {
            var hasher = Hasher()
            for (_, snapshot) in snapshots {
                hasher.combine(snapshot)
            }
            return hasher.finalize()
        }()

        let xPercentDatePair: [(Double, Date, Int)] = {
            let calendar = Calendar(identifier: .gregorian)
            let components = calendar.dateComponents([.year, .month, .day, .hour], from: state.dateRange.lowerBound)
            var date = calendar.date(from: components)!
            var results = [(Double, Date, Int)]()
            var index: Int = 0
            while true {
                defer {
                    date.addTimeInterval(state.satelliteElevationGraphConfigs.timeGridLineInterval)
                }
                if date < state.dateRange.lowerBound {
                    continue
                }
                let xPercent = date.timeIntervalSince(state.dateRange.lowerBound) / (state.dateRange.upperBound.timeIntervalSince(state.dateRange.lowerBound))
                if xPercent > 1 {
                    break
                }
                results.append((xPercent, date, index))
                index += 1
            }
            return results
        }()

        let contentRect: (CGRect) -> CGRect = { initialRect in
            let widthPerSecond = initialRect.width / CGFloat(state.dateRange.upperBound.timeIntervalSince(state.dateRange.lowerBound))
            return CGRect(origin: initialRect.origin, size: CGSize(width: initialRect.width / widthPerSecond * max(widthPerSecond, state.satelliteElevationGraphConfigs.minimumHorizonalResolution), height: initialRect.height))
        }

        let snapshotsSplitByIllumination = Array(snapshots.enumerated())
            .map { ($0, $1.1) }
            .split(shouldSplit: { (s1, s2) -> Bool in
                return s1.1.isIlluminated != s2.1.isIlluminated
            })

        return SatelliteElevationGraphState(
            satelliteElevationPath: satelliteElevationPathFunc(
                snapshots: snapshots,
                snapshotsHash: snapshotsHash
            ),
            unilluminatedPaths: unilluminatedPathsFunc(
                snapshotsSplitByIllumination: snapshotsSplitByIllumination,
                snapshotsHash: snapshotsHash,
                totalCount: snapshots.count
            ),
            xPercentDatePair: xPercentDatePair,
            contentRect: contentRect,
            snapshots: snapshots,
            dateRange: state.dateRange,
            elevationGridLineInterval: state.satelliteElevationGraphConfigs.elevationGridLineInterval
        )
    }
}

struct SatelliteElevationGraph: View {
    @ObservedObject var viewModel: ObservableViewModel<SatelliteElevationGraphAction, SatelliteElevationGraphState>
    @State private var contentSize: CGSize = .zero
    @State private var longPressLocation: CGPoint?

    private var timeGrid: some View {
        GeometryReader { geometry in
            let rect = geometry.frame(in: .local)

            Path { path in
                for (xPercent, _, _) in viewModel.state.xPercentDatePair {
                    let x = CGFloat(xPercent) * rect.width
                    // Do not draw vertical lines that are too close to the edges
                    if x - rect.minX < 20 || rect.maxX - x < 20 {
                        continue
                    }
                    path.move(to: CGPoint(x: x, y: rect.minY))
                    path.addLine(to: CGPoint(x: x, y: rect.maxY))
                }
            }
            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        }
    }

    private var elevationGrid: some View {
        GeometryReader { geometry in
            let rect = geometry.frame(in: .local)
            let elevIterator = stride(from: -90.0, to: 90.0, by: viewModel.state.elevationGridLineInterval)
            ZStack {
                Path { path in
                    elevIterator.forEach { elev in
                        let y = CGFloat(elev + 90) / 180 * rect.height
                        path.move(to: CGPoint(x: rect.minX, y: y))
                        path.addLine(to: CGPoint(x: rect.maxX, y: y))
                    }
                }
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)

                Path { path in
                    path.move(to: CGPoint(x: rect.minX, y: rect.midY))
                    path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
                }
                .stroke(Color.gray, lineWidth: 1)
            }
        }
    }

    private var elevationText: some View {
        ZStack {
            let elevIterator = stride(from: -90.0, to: 90.0, by: viewModel.state.elevationGridLineInterval)

            ForEach(Array(elevIterator), id: \.self) { elev in
                let y = CGFloat(elev + 90) / 180 * self.contentSize.height

                Text("\(Int(-elev))º")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .frame(height: 30, alignment: .bottomTrailing)
                    .position(x: 15, y: y)
            }
        }
    }

    private var satelliteElevationPlot: some View {
        GeometryReader { geometry in
            let rect = geometry.frame(in: .local)

            Path(viewModel.state.satelliteElevationPath(rect))
            .stroke(
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue, Color.red]),
                    startPoint: .bottom,
                    endPoint: .top
                ),
                lineWidth: 2
            )
        }
    }

    /// An overlay on satellite elevation plot to indicate satellite in these ranges are not illuminated by the sun.
    private var satelliteDarknessPath: some View {
        GeometryReader { geometry in
            let rect = geometry.frame(in: .local)

            Path(viewModel.state.unilluminatedPaths(rect))
            .stroke(
                Color(white: 0.8),
                lineWidth: 2
            )
        }
    }

    private var selectedTimeInfo: some View {
        if let longPressLocation = longPressLocation {
            return AnyView(
                GeometryReader { geometry in
                    let rect = geometry.frame(in: .local)
                    Path { path in
                        path.move(to: CGPoint(x: longPressLocation.x, y: rect.minY))
                        path.addLine(to: CGPoint(x: longPressLocation.x, y: rect.maxY))
                    }
                    .stroke(
                        style: StrokeStyle(lineWidth: 1)
                    )
                    .foregroundColor(.orange)
                }
                .allowsHitTesting(false)
            )
        } else {
            return AnyView(EmptyView().allowsHitTesting(false))
        }
    }

    struct LongPressGestureModifier: ViewModifier {
        @Binding var longPressLocation: CGPoint?

        func body(content: Content) -> some View {
            content.highPriorityGesture(
                LongPressGesture(minimumDuration: 0.75)
                    .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
                    .onChanged({ value in
                        switch value {
                        case .second(true, let drag):
                            self.longPressLocation = drag?.location
                        default:
                            break
                        }
                    })
                    .onEnded { value in
                        switch value {
                        case .second(true, _):
                            self.longPressLocation = nil
                        default:
                            break
                        }
                    }
            )
        }
    }

    let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm a"
        return formatter
    }()

    var body: some View {
        GeometryReader { geometry in
            let initialRect = geometry.frame(in: .local)
            let rect = viewModel.state.contentRect(initialRect)

            ZStack {
                ScrollView(
                    .horizontal,
                    showsIndicators: false,
                    content: {
                        VStack(
                            alignment: .leading,
                            spacing: 4
                        ) {
                            timeGrid
                                .overlay(elevationGrid)
                                .overlay(satelliteElevationPlot)
                                .overlay(satelliteDarknessPath)
                                .modifier(LongPressGestureModifier(longPressLocation: self.$longPressLocation))
                                .modifier(SizeModifier())
                                .onPreferenceChange(SizePreferenceKey.self) { self.contentSize = $0 }
                                .overlay(selectedTimeInfo)

                            SunlightIndicator(
                                viewModel: SunlightIndicatorViewModel(
                                    snapshots: viewModel.state.snapshots,
                                    dateRange: viewModel.state.dateRange
                                )
                            )
                            .frame(height: 24)

                            HStack(alignment: .center, spacing: 0) {
                                ForEach(viewModel.state.xPercentDatePair, id: \.0) { (xPercent, date, index) in
                                    VStack {
                                        Text(
                                            formatter.string(from: date)
                                        )
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .frame(width: 80)
                                        .offset(x: CGFloat(xPercent) * rect.width - CGFloat(index) * 80 - 40)
                                    }
                                }
                            }
                        }
                        .frame(
                            width: max(0, rect.width),
                            height: max(0, rect.height),
                            alignment: .leading
                        )
                    }
                )

                elevationText
            }
        }
    }
}

import CombineRextensions

extension ViewProducer where Context == Void, ProducedView == SatelliteElevationGraph {
    static func satelliteElevationGraph<S: StoreType>(viewModel: S) -> ViewProducer where S.ActionType == AppAction, S.StateType == AppState {
        ViewProducer<Context, ProducedView> {
            SatelliteElevationGraph(
                viewModel: viewModel
                    .projection(
                        action: { AppAction.satelliteElevationGraph($0) },
                        state: SatelliteElevationGraphState.project(state:)
                    )
                    .asObservableViewModel(initialState: .empty)
            )
        }
    }
}

struct SatelliteElevationGraph_Previews: PreviewProvider {
    static var previews: some View {
        let tle = try! TLE(
            raw: """
            ISS (ZARYA)
            1 25544U 98067A   21152.11066515  .00000451  00000-0  16375-4 0  9992
            2 25544  51.6453  62.2423 0003364  52.3737  88.5313 15.48937685286109
            """
        )
        let sat = Satellite(withTLE: tle)
        // Date range
        let dateRange = Date().advanced(by: -60 * 60 * 2)..<Date().advanced(by: 60 * 60 * 4)
        // 2000 Broadway, Redwood City, CA 94063
        let location = CLLocation(latitude: 37.486743000691185, longitude: -122.22655970246515)
        let viewModel = SatelliteElevationGraphState.project(
            state: AppState(
                dateRange: dateRange,
                satellites: [
                    Int(sat.noradIdent)!: SatelliteState(
                        snapshots: sat.snapshots(
                            observer: LatLonAlt(location: location),
                            dateRange: dateRange,
                            interval: 20
                        ),
                        passes: []
                    )
                ],
                tleLoaderState: TLELoaderState(standaloneTLEs: [tle]),
                coreLocationState: CoreLocationState(
                    authorizationStatus: .authorizedWhenInUse,
                    location: location
                ),
                selectedSatelliteNoradIndex: Int(sat.noradIdent)!
            )
        )
        SatelliteElevationGraph(viewModel: .mock(state: viewModel))
            .previewLayout(.fixed(width: 720, height: 240))
            .previewDisplayName("ISS")

        let tle2 = try! TLE(
            raw: """
            DFH-1
            1 04382U 70034A   21154.78159189  .00001370  00000-0  21022-3 0  9993
            2 04382  68.4187 192.6131 1052892 188.4862 169.7083 13.08082975404634
            """
        )
        let sat2 = Satellite(withTLE: tle2)
        let viewModel2 = SatelliteElevationGraphState.project(
            state: AppState(
                dateRange: dateRange,
                satellites: [
                    Int(sat2.noradIdent)!: SatelliteState(
                        snapshots: sat2.snapshots(
                            observer: LatLonAlt(location: location),
                            dateRange: dateRange,
                            interval: 20
                        ),
                        passes: []
                    )
                ],
                tleLoaderState: TLELoaderState(standaloneTLEs: [tle2]),
                coreLocationState: CoreLocationState(
                    authorizationStatus: .authorizedWhenInUse,
                    location: location
                ),
                selectedSatelliteNoradIndex: Int(sat2.noradIdent)!
            )
        )
        SatelliteElevationGraph(viewModel: .mock(state: viewModel2))
            .previewLayout(.fixed(width: 720, height: 240))
            .previewDisplayName("DFH-1")

        let tle3 = try! TLE(
            raw: """
            MOLNIYA 2-9
            1 07276U 74026A   21154.36625011 -.00000128  00000-0  00000-0 0  9990
            2 07276  64.2122 283.1177 6670908 285.3565  14.2908  2.45094844240000
            """
        )
        let sat3 = Satellite(withTLE: tle3)
        let viewModel3 = SatelliteElevationGraphState.project(
            state: AppState(
                dateRange: dateRange,
                satellites: [
                    Int(sat3.noradIdent)!: SatelliteState(
                        snapshots: sat3.snapshots(
                            observer: LatLonAlt(location: location),
                            dateRange: dateRange,
                            interval: 20
                        ),
                        passes: []
                    )
                ],
                tleLoaderState: TLELoaderState(standaloneTLEs: [tle3]),
                coreLocationState: CoreLocationState(
                    authorizationStatus: .authorizedWhenInUse,
                    location: location
                ),
                selectedSatelliteNoradIndex: Int(sat3.noradIdent)!
            )
        )
        SatelliteElevationGraph(viewModel: .mock(state: viewModel3))
            .previewLayout(.fixed(width: 720, height: 240))
            .previewDisplayName("Molniya 2-9")

    }
}
