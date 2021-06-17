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
        return lhs.snapshots == rhs.snapshots && lhs.julianDateRange == rhs.julianDateRange && lhs.elevationGridLineInterval == rhs.elevationGridLineInterval && lhs.highlightedDateRange == rhs.highlightedDateRange
    }

    private static func snapshotPoint(_ snapshot: SatelliteSnapshot, xPercent: CGFloat, rect: CGRect) -> CGPoint {
        let x = rect.width * xPercent
        let y = CGFloat(snapshot.position.elev + 90) / 180 * -rect.height + rect.height
        return CGPoint(x: x, y: y)
    }

    private static var satelliteElevationCache: (Int, CGPath)?

    private static func satelliteElevationPathFunc(
        snapshots: Map<Double, SatelliteSnapshot>,
        snapshotsHash: Int,
        julianDateRange: Range<Double>
    ) -> (CGRect) -> CGPath {
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

            for (i, (julianDate, snapshot)) in snapshots.enumerated() {
                let xPercent = CGFloat((julianDate - julianDateRange.lowerBound) / (julianDateRange.upperBound - julianDateRange.lowerBound))
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
        snapshotsSplitByIllumination: [Map<Double, SatelliteSnapshot>],
        snapshotsHash: Int,
        julianDateRange: Range<Double>
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
                    for index in snapshotGroup.indices {
                        let (julianDate, snapshot) = snapshotGroup[index]
                        let xPercent = CGFloat((julianDate - julianDateRange.lowerBound) / (julianDateRange.upperBound - julianDateRange.lowerBound))
                        if index == snapshotGroup.startIndex {
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
    fileprivate let xPercentDatePair: [(Double, Double, Int)]
    fileprivate let contentRect: (CGRect) -> CGRect

    // Copied properties
    fileprivate let snapshots: Map<Double, SatelliteSnapshot>
    /// Date range for display.
    fileprivate let julianDateRange: Range<Double>
    fileprivate let elevationGridLineInterval: Double
    fileprivate let highlightedDateRange: Range<Double>?

    static var empty: SatelliteElevationGraphState {
        .init(
            satelliteElevationPath: { _ in CGMutablePath() },
            unilluminatedPaths: { _ in CGMutablePath() },
            xPercentDatePair: [],
            contentRect: { $0 },
            snapshots: Map<Double, SatelliteSnapshot>(),
            julianDateRange: Date().advanced(by: -60 * 60 * 2).julianDate..<Date().advanced(by: 60 * 60 * 22).julianDate,
            elevationGridLineInterval: 30,
            highlightedDateRange: nil
        )
    }

    init(
        satelliteElevationPath: @escaping (CGRect) -> CGPath,
        unilluminatedPaths: @escaping (CGRect) -> CGPath,
        xPercentDatePair: [(Double, Double, Int)],
        contentRect: @escaping (CGRect) -> CGRect,
        snapshots: Map<Double, SatelliteSnapshot>,
        julianDateRange: Range<Double>,
        elevationGridLineInterval: Double,
        highlightedDateRange: Range<Double>?
    ) {
        self.satelliteElevationPath = satelliteElevationPath
        self.unilluminatedPaths = unilluminatedPaths
        self.xPercentDatePair = xPercentDatePair
        self.contentRect = contentRect
        self.snapshots = snapshots
        self.julianDateRange = julianDateRange
        self.elevationGridLineInterval = elevationGridLineInterval
        self.highlightedDateRange = highlightedDateRange
    }

    static func project(state: Store.StateType) -> SatelliteElevationGraphState {
        // The view model's snapshot will be constrained to the date range.
        let snapshots = state.currentSatelliteSnapshots.submap(
            from: state.julianDateRange.lowerBound,
            to: state.julianDateRange.upperBound
        )
        let snapshotsHash: Int = {
            var hasher = Hasher()
            for (_, snapshot) in snapshots {
                hasher.combine(snapshot)
            }
            return hasher.finalize()
        }()

        let xPercentDatePair: [(Double, Double, Int)] = {
            let calendar = Calendar(identifier: .gregorian)
            let components = calendar.dateComponents([.year, .month, .day, .hour], from: Date(julianDate: state.julianDateRange.lowerBound))
            var julianDate: Double = calendar.date(from: components)!.julianDate
            var results = [(Double, Double, Int)]()
            var index: Int = 0
            while true {
                defer {
                    julianDate += TimeConstants.sec2day * state.satelliteElevationGraphConfigs.timeGridLineInterval
                }
                if julianDate < state.julianDateRange.lowerBound {
                    continue
                }
                let xPercent = (julianDate - state.julianDateRange.lowerBound) / (state.julianDateRange.upperBound - state.julianDateRange.lowerBound)
                if xPercent > 1 {
                    break
                }
                results.append((xPercent, julianDate, index))
                index += 1
            }
            return results
        }()

        let contentRect: (CGRect) -> CGRect = { initialRect in
            let widthPerSecond = initialRect.width / CGFloat((state.julianDateRange.upperBound - state.julianDateRange.lowerBound) * TimeConstants.day2sec)
            return CGRect(origin: initialRect.origin, size: CGSize(width: initialRect.width / widthPerSecond * max(widthPerSecond, state.satelliteElevationGraphConfigs.minimumHorizonalResolution), height: initialRect.height))
        }

        let snapshotsSplitByIllumination = snapshots
            .split(shouldSplit: { (s1, s2) -> Bool in
                return s1.1.isIlluminated != s2.1.isIlluminated
            })

        return SatelliteElevationGraphState(
            satelliteElevationPath: satelliteElevationPathFunc(
                snapshots: snapshots,
                snapshotsHash: snapshotsHash,
                julianDateRange: state.julianDateRange
            ),
            unilluminatedPaths: unilluminatedPathsFunc(
                snapshotsSplitByIllumination: snapshotsSplitByIllumination,
                snapshotsHash: snapshotsHash,
                julianDateRange: state.julianDateRange
            ),
            xPercentDatePair: xPercentDatePair,
            contentRect: contentRect,
            snapshots: snapshots,
            julianDateRange: state.julianDateRange,
            elevationGridLineInterval: state.satelliteElevationGraphConfigs.elevationGridLineInterval,
            highlightedDateRange: state.selectedSatellitePass.map { pass -> Range<Double> in
                return pass.rise.julianDate..<pass.set.julianDate
            }
        )
    }
}

struct SatelliteElevationGraph: View {
    @ObservedObject var viewModel: ObservableViewModel<SatelliteElevationGraphAction, SatelliteElevationGraphState>
    @State private var contentSize: CGSize = .zero

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

                Text("\(Int(-elev))°")
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

    private var dateLabels: some View {
        GeometryReader { geometry in
            let rect = geometry.frame(in: .local)
            let julianDateRange = viewModel.state.julianDateRange
            let calendar = Calendar(identifier: .gregorian)
            let components = calendar.dateComponents([.year, .month, .day], from: Date(julianDate: julianDateRange.lowerBound))

            let dates: [Date] = {
                var date = calendar.date(from: components)!
                var dates = [Date]()
                while true {
                    defer {
                        date = date.advanced(by: 60 * 60 * 24)
                    }
                    if date < Date(julianDate: julianDateRange.lowerBound) {
                        continue
                    }
                    if date >= Date(julianDate: julianDateRange.upperBound) {
                        break
                    }
                    dates.append(date)
                }
                return dates
            }()


            ForEach(dates, id: \.self) { date in
                HStack {
                    Text(dateFormatter.string(from: date.advanced(by: -60 * 60 * 24)))
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(.gray)
                        .font(.caption2)
                    Text(dateFormatter.string(from: date))
                        .foregroundColor(.gray)
                        .font(.caption2)
                }
                .frame(height: rect.height, alignment: .top)
                .position(x: rect.width * CGFloat((date.julianDate - julianDateRange.lowerBound) / (julianDateRange.upperBound - julianDateRange.lowerBound)), y: rect.midY)
                .fixedSize()
            }
        }
    }

    private var highlightedPassRegion: some View {
        GeometryReader { geometry in
            let rect = geometry.frame(in: .local)
            let julianDateRange = viewModel.state.julianDateRange
            if let highlightedDateRange = viewModel.state.highlightedDateRange {
                let fromX = CGFloat((highlightedDateRange.lowerBound - julianDateRange.lowerBound) / (julianDateRange.upperBound - julianDateRange.lowerBound)) * rect.width
                let toX = CGFloat((highlightedDateRange.upperBound - julianDateRange.lowerBound) / (julianDateRange.upperBound - julianDateRange.lowerBound)) * rect.width
                HStack(spacing: 0) {
                    Spacer(minLength: fromX)
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(
                                    stops: [
                                        Gradient.Stop(color: Color.yellow.opacity(0), location: 0),
                                        Gradient.Stop(color: Color.yellow.opacity(0.2), location: 0.1),
                                        Gradient.Stop(color: Color.yellow.opacity(0.3), location: 1)
                                    ]
                                ),
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .id("centerAtDate")
                    Spacer(minLength: rect.width - toX)
                }
            }
        }
    }

    let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm a"
        return formatter
    }()

    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM dd")
        return formatter
    }()

    func innerViews(rect: CGRect) -> some View {
        VStack(
            alignment: .leading,
            spacing: 4
        ) {
            timeGrid
                .overlay(elevationGrid)
                .overlay(satelliteElevationPlot)
                .overlay(satelliteDarknessPath)
                .modifier(SizeModifier())
                .onPreferenceChange(SizePreferenceKey.self) { self.contentSize = $0 }
                .overlay(highlightedPassRegion)
                .overlay(dateLabels)

            SunlightIndicator(
                viewModel: SunlightIndicatorViewModel(
                    snapshots: viewModel.state.snapshots,
                    julianDateRange: viewModel.state.julianDateRange
                )
            )
            .frame(height: 24)

            HStack(alignment: .center, spacing: 0) {
                ForEach(viewModel.state.xPercentDatePair, id: \.0) { (xPercent, julianDate, index) in
                    VStack {
                        Text(
                            timeFormatter.string(from: Date(julianDate: julianDate))
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

    var body: some View {
        GeometryReader { geometry in
            let initialRect = geometry.frame(in: .local)
            let rect = viewModel.state.contentRect(initialRect)

            ZStack {
                ScrollView(
                    .horizontal,
                    showsIndicators: false,
                    content: {
                        ScrollViewReader { scrollViewProxy in
                            innerViews(
                                rect: rect
                            )
                            .onChange(
                                of: viewModel.state.highlightedDateRange,
                                perform: { _ in
                                    scrollViewProxy.scrollTo("centerAtDate", anchor: .center)
                                }
                            )
                        }
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
        let julianDateRange = Date().advanced(by: -60 * 60 * 2).julianDate..<Date().advanced(by: 60 * 60 * 4).julianDate
        // 2000 Broadway, Redwood City, CA 94063
        let location = CLLocation(latitude: 37.486743000691185, longitude: -122.22655970246515)
        let viewModel = SatelliteElevationGraphState.project(
            state: AppState(
                julianDateRange: julianDateRange,
                satellites: [
                    Int(sat.noradIdent)!: SatelliteState(
                        snapshots: sat.snapshots(
                            observer: LatLonAlt(location: location),
                            julianDateRange: julianDateRange,
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
                navigationState: .allPasses(noradIndex: Int(sat.noradIdent)!)
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
                julianDateRange: julianDateRange,
                satellites: [
                    Int(sat2.noradIdent)!: SatelliteState(
                        snapshots: sat2.snapshots(
                            observer: LatLonAlt(location: location),
                            julianDateRange: julianDateRange,
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
                navigationState: .allPasses(noradIndex: Int(sat2.noradIdent)!)
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
                julianDateRange: julianDateRange,
                satellites: [
                    Int(sat3.noradIdent)!: SatelliteState(
                        snapshots: sat3.snapshots(
                            observer: LatLonAlt(location: location),
                            julianDateRange: julianDateRange,
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
                navigationState: .allPasses(noradIndex: Int(sat3.noradIdent)!)
            )
        )
        SatelliteElevationGraph(viewModel: .mock(state: viewModel3))
            .previewLayout(.fixed(width: 720, height: 240))
            .previewDisplayName("Molniya 2-9")

    }
}
