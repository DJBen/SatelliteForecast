//
//  SatelliteElevationGraph.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/2/21.
//

import BTree
import CombineRex
import SwiftUI
import SatelliteKit
import SatelliteForecastCore
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
    case requestRasterizeElevationGraph(
        size: CGSize,
        noradIndex: Int,
        julianDateRange: Range<Double>,
        traitCollection: UITraitCollection
    )
    case rasterizedElevationGraph(UIImage, size: CGSize, noradIndex: Int, julianDateRange: Range<Double>)
}

struct SatelliteElevationGraphState: Equatable {
    let noradIndex: Int
    let currentJulianDate: Double
    let currentSnapshot: SatelliteSnapshot
    /// Date range for display.
    let julianDateRange: Range<Double>
    let highlightedDateRange: Range<Double>?
    let julianDateSunElevs: BTree<Double, Double>
    let rasterizedElevationGraph: UIImage?
    let configs: SatelliteElevationGraphConfigs

    static func project(state: Store.StateType) -> SatelliteElevationGraphState? {
        let satelliteElevationGraphConfigs: SatelliteElevationGraphConfigs = .preset

        guard let julianDateRange = state.julianDateRange else {
            return nil
        }

        guard let observer = state.observerForPasses else {
            return nil
        }

        guard let noradIndex = state.navigationState.selectedSatelliteNoradIndex,
              let satellite = state.satelliteLoaderState[noradIndex] else {
            return nil
        }

        let rasterizedElevationGraph: UIImage? = {
            guard let rangeImage = state.satelliteElevationGraphResources.rasterizedElevationGraphs[noradIndex] else {
                return nil
            }
            let (imageJulianDateRange, image) = (rangeImage.julianDateRange, rangeImage.image)
            // Reuses the image if the previously calculated date range is within 10 mins away from current requested date range
            if abs(imageJulianDateRange.lowerBound - julianDateRange.lowerBound) < 10 * TimeConstants.min2day && abs(imageJulianDateRange.upperBound - julianDateRange.upperBound) < 10 * TimeConstants.min2day  {
                return image
            }

            return nil
        }()

        return SatelliteElevationGraphState(
            noradIndex: noradIndex,
            currentJulianDate: state.julianDate,
            currentSnapshot: satellite.satellite.snapshot(
                julianDate: state.julianDate,
                observer: observer
            ),
            julianDateRange: julianDateRange,
            highlightedDateRange: state.selectedSatellitePass.map { pass -> Range<Double> in
                return pass.rise.julianDate..<pass.set.julianDate
            },
            julianDateSunElevs: state.currentSatelliteSnapshots.map { ($0, $1.sunElevation) }
                .reduce(into: BTree<Double, Double>(), { $0.insertOrReplace($1) }),
            rasterizedElevationGraph: rasterizedElevationGraph,
            configs: satelliteElevationGraphConfigs
        )
    }
}

struct SatelliteElevationGraph: View {
    @ObservedObject var viewModel: ObservableViewModel<SatelliteElevationGraphAction, SatelliteElevationGraphState?>
    @State private var graphingRegionSize: CGSize = .zero
    @Environment(\.colorScheme) var colorScheme

    struct PercentDate: Equatable {
        let percent: Double
        let julianDate: Double
    }
    
    @ViewBuilder private func unwrapState<Content: View>(@ViewBuilder content: (SatelliteElevationGraphState) -> Content) -> some View {
        if let state = viewModel.state {
            content(state)
        }
    }

    private var elevationText: some View {
        unwrapState { state in
            ZStack {
                if graphingRegionSize.width == 0 || graphingRegionSize.height == 0 {
                    EmptyView()
                } else {
                    let elevIterator = stride(from: -90.0, to: 90.0, by: state.configs.elevationGridLineInterval)

                    ForEach(Array(elevIterator), id: \.self) { elev in
                        let y = CGFloat(elev + 90) / 180 * self.graphingRegionSize.height

                        Text("\(Int(-elev))°")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .frame(height: 30, alignment: .bottomTrailing)
                            .position(x: 15, y: y)
                    }
                }
            }
        }
    }

    private var satelliteElevationPlot: some View {
        unwrapState { state in
            GeometryReader { geometry in
                let rect = geometry.frame(in: .local)
                if let image = state.rasterizedElevationGraph {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: rect.width, height: rect.height, alignment: .center)
                }
            }
        }
    }

    private var dateBoundaryLabels: some View {
        unwrapState { state in
            GeometryReader { geometry in
                let rect = geometry.frame(in: .local)
                let julianDateRange = state.julianDateRange
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
    }

    private var highlightedPassRegion: some View {
        unwrapState { state in
            GeometryReader { geometry in
                let rect = geometry.frame(in: .local)
                let julianDateRange = state.julianDateRange
                if let highlightedDateRange = state.highlightedDateRange {
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
    }

    private var currentIndicator: some View {
        unwrapState { state in
            let x = (state.currentJulianDate - state.julianDateRange.lowerBound) / (state.julianDateRange.upperBound - state.julianDateRange.lowerBound)
            let y = 1 - (state.currentSnapshot.position.elev + 90) / 180

            SatelliteElevationGraphCurrentIndicator(percentageCoordinate: CGPoint(x: x, y: y))
        }
    }

    @ViewBuilder private var background: some View {
        unwrapState { state in
            SatelliteElevationGraphBackground(
                state: SatelliteElevationGraphBackgroundState(julianDateRange: state.julianDateRange, configs: state.configs),
                graphingRegionSize: $graphingRegionSize
            )
            .equatable()
            .onChange(of: graphingRegionSize) { size in
                if size.width == 0 || size.height == 0 {
                    return
                }

                let traitCollection = UITraitCollection(userInterfaceStyle: UIUserInterfaceStyle(colorScheme))

                viewModel.dispatch(
                    .requestRasterizeElevationGraph(
                        size: size,
                        noradIndex: state.noradIndex,
                        julianDateRange: state.julianDateRange,
                        traitCollection: traitCollection
                    )
                )
            }
        }
    }

    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM dd")
        return formatter
    }()

    func innerViews(rect: CGRect) -> some View {
        unwrapState { state in
            VStack(
                alignment: .leading,
                spacing: 4
            ) {
                background
                    .overlay(satelliteElevationPlot)
                    .overlay(highlightedPassRegion)
                    .overlay(dateBoundaryLabels)
                    .overlay(currentIndicator)

                SunlightIndicator(
                    viewModel: SunlightIndicatorViewModel(
                        julianDateElevations: state.julianDateSunElevs
                    )
                )
                .equatable()
                .frame(height: 24)

                DateFooter(
                    state: DateFooterState(
                        julianDateRange: state.julianDateRange,
                        configs: state.configs
                    ),
                    width: rect.width
                )
                .equatable()
            }
            .frame(
                width: max(0, rect.width),
                height: max(0, rect.height),
                alignment: .leading
            )
        }
    }

    var body: some View {
        unwrapState { state in
            GeometryReader { geometry in
                let initialRect = geometry.frame(in: .local)
                let widthPerSecond = initialRect.width / CGFloat((state.julianDateRange.upperBound - state.julianDateRange.lowerBound) * TimeConstants.day2sec)
                let rect = CGRect(origin: initialRect.origin, size: CGSize(width: initialRect.width / widthPerSecond * max(widthPerSecond, state.configs.minimumHorizonalResolution), height: initialRect.height))

                ZStack {
                    ScrollView(
                        .horizontal,
                        showsIndicators: false,
                        content: {
                            ScrollViewReader { scrollViewProxy in
                                if rect.isEmpty {
                                    EmptyView()
                                } else {
                                    innerViews(
                                        rect: rect
                                    )
                                    .onAppear {
                                        if let _ = state.highlightedDateRange {
                                            scrollViewProxy.scrollTo("centerAtDate", anchor: .center)
                                        }
                                    }
                                    .onChange(
                                        of: state.highlightedDateRange,
                                        perform: { _ in
                                            scrollViewProxy.scrollTo("centerAtDate", anchor: .center)
                                        }
                                    )
                                }
                            }
                        }
                    )

                    elevationText
                }
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
                    .asObservableViewModel(initialState: nil)
            )
        }
    }
}

#if DEBUG
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
                satellites: [
                    Int(sat.noradIdent)!: SatelliteTrails(
                        snapshots: sat.snapshots(
                            observer: LatLonAlt(location: location),
                            julianDateRange: julianDateRange,
                            interval: 20
                        ),
                        passes: nil
                    )
                ],
                satelliteLoaderState: SatelliteLoaderState(
                    standaloneInfo: [tle.noradIndex: SatelliteInfo(noradIndex: tle.noradIndex, satellite: sat)]
                ),
                coreLocationState: CoreLocationState(
                    authorizationStatus: .authorizedWhenInUse,
                    location: location
                ),
                julianDateRange: julianDateRange,
                navigationState: .allPasses(category: nil, noradIndex: Int(sat.noradIdent)!)
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
                satellites: [
                    Int(sat2.noradIdent)!: SatelliteTrails(
                        snapshots: sat2.snapshots(
                            observer: LatLonAlt(location: location),
                            julianDateRange: julianDateRange,
                            interval: 20
                        ),
                        passes: nil
                    )
                ],
                satelliteLoaderState: SatelliteLoaderState(
                    standaloneInfo: [tle2.noradIndex: SatelliteInfo(noradIndex: tle2.noradIndex, satellite: sat2)]
                ),
                coreLocationState: CoreLocationState(
                    authorizationStatus: .authorizedWhenInUse,
                    location: location
                ),
                julianDateRange: julianDateRange,
                navigationState: .allPasses(category: nil, noradIndex: Int(sat2.noradIdent)!)
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
                satellites: [
                    Int(sat3.noradIdent)!: SatelliteTrails(
                        snapshots: sat3.snapshots(
                            observer: LatLonAlt(location: location),
                            julianDateRange: julianDateRange,
                            interval: 20
                        ),
                        passes: nil
                    )
                ],
                satelliteLoaderState: SatelliteLoaderState(
                    standaloneInfo: [tle3.noradIndex: SatelliteInfo(noradIndex: tle3.noradIndex, satellite: sat3)]
                ),
                coreLocationState: CoreLocationState(
                    authorizationStatus: .authorizedWhenInUse,
                    location: location
                ),
                julianDateRange: julianDateRange,
                navigationState: .allPasses(category: nil, noradIndex: Int(sat3.noradIdent)!)
            )
        )
        SatelliteElevationGraph(viewModel: .mock(state: viewModel3))
            .previewLayout(.fixed(width: 720, height: 240))
            .previewDisplayName("Molniya 2-9")

    }
}
#endif
