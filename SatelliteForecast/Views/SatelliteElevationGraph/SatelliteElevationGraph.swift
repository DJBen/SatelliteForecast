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
        noradIndex: UInt,
        julianDateRange: ClosedRange<Double>,
        traitCollection: UITraitCollection
    )
    case rasterizedElevationGraph(UIImage, size: CGSize, noradIndex: UInt, julianDateRange: ClosedRange<Double>)
}

struct SatelliteElevationGraphContext {
    let satelliteInfo: SatelliteInfo
    let julianDateRange: ClosedRange<Double>
    let observer: LatLonAlt
    let configs: SatelliteElevationGraphConfigs
    /// Because we are showing a time window of satellite elevations, as time ticks every few seconds,
    /// the time window of the satellite elevations (usually spanning a few days) shifts forward by that amount of seconds.
    /// To prevent generating graph at a high frequency, this time is time spent before generating a new elevation graph.
    let elevationGraphTolerance: Double = TimeConstants.min2day
}

struct SatelliteElevationGraphState: Equatable {
    var currentJulianDate: Double = 0
    var satelliteElevationGraphResources: SatelliteElevationGraphResources = .init()
    var highlightedDateRange: ClosedRange<Double>?
}

struct SatelliteElevationGraph: View {
    @ObservedObject var viewModel: ObservableViewModel<SatelliteElevationGraphAction, SatelliteElevationGraphState>
    let context: SatelliteElevationGraphContext
    
    @State private var graphingRegionSize: CGSize = .zero
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.julianDateRangeKey) var julianDateRange

    struct PercentDate: Equatable {
        let percent: Double
        let julianDate: Double
    }

    var rasterizedElevationGraph: UIImage? {
        guard let julianDateRange = julianDateRange else {
            return nil
        }
        guard let rangeImage = viewModel.state.satelliteElevationGraphResources.rasterizedElevationGraph(
            noradIndex: context.satelliteInfo.noradIndex,
            size: graphingRegionSize,
            julianDateRange: julianDateRange,
            tolerance: TimeConstants.min2day
        ) else {
            return nil
        }
        return rangeImage.image
    }

    var julianDateSunElevs: [Double: Double] {
        guard let julianDateRange = julianDateRange else {
            return [:]
        }
        return SunlightIndicator.sunElevations(
            julianDateRange: julianDateRange,
            observer: context.observer
        )
    }

    var currentSnapshot: SatelliteSnapshot {
        try! context.satelliteInfo.generateSnapshot(
            julianDate: viewModel.state.currentJulianDate,
            observer: context.observer
        )
    }

    private var elevationText: some View {
        ZStack {
            if graphingRegionSize.width == 0 || graphingRegionSize.height == 0 {
                EmptyView()
            } else {
                let elevIterator = stride(from: -90.0, to: 90.0, by: context.configs.elevationGridLineInterval)

                ForEach(Array(elevIterator), id: \.self) { elev in
                    let y = CGFloat(elev + 90) / 180 * self.graphingRegionSize.height

                    Text(
                        "\(Int(-elev))°"
                    )
                    .font(.caption)
                    .foregroundColor(.gray)
                    .frame(height: 30, alignment: .bottomTrailing)
                    .position(x: 15, y: y)
                }
            }
        }
    }

    private var satelliteElevationPlot: some View {
        GeometryReader { geometry in
            let rect = geometry.frame(in: .local)
            if let image = rasterizedElevationGraph {
                Image(
                    uiImage: image
                )
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: rect.width, height: rect.height, alignment: .center)
            }
        }
    }

    private var dateBoundaryLabels: some View {
        julianDateRangePresent { julianDateRange in
            GeometryReader { geometry in
                let rect = geometry.frame(in: .local)
                let calendar = Calendar(identifier: .gregorian)
                let components = calendar.dateComponents(
                    [.year, .month, .day],
                    from: Date(julianDate: julianDateRange.lowerBound)
                )

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
        julianDateRangePresent { julianDateRange in
            GeometryReader { geometry in
                let rect = geometry.frame(in: .local)
                if let highlightedDateRange = viewModel.state.highlightedDateRange {
                    let fromX = CGFloat((highlightedDateRange.lowerBound - julianDateRange.lowerBound) / (julianDateRange.upperBound - julianDateRange.lowerBound)) * rect.width
                    let toX = CGFloat((highlightedDateRange.upperBound - julianDateRange.lowerBound) / (julianDateRange.upperBound - julianDateRange.lowerBound)) * rect.width
                    HStack(spacing: 0) {
                        Spacer(minLength: fromX)
                        Rectangle(
                        )
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

    @ViewBuilder private var currentIndicator: some View {
        julianDateRangePresent { julianDateRange in
            let state = viewModel.state
            let x = (state.currentJulianDate - julianDateRange.lowerBound) / (julianDateRange.upperBound - julianDateRange.lowerBound)
            let y = 1 - (currentSnapshot.position.elev + 90) / 180

            SatelliteElevationGraphCurrentIndicator(
                percentageCoordinate: CGPoint(x: x, y: y),
                currentJulianDate: state.currentJulianDate
            )
        }
    }

    @ViewBuilder private var background: some View {
        julianDateRangePresent { julianDateRange in
            SatelliteElevationGraphBackground(
                state: SatelliteElevationGraphBackgroundState(julianDateRange: julianDateRange, configs: context.configs),
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
                        noradIndex: context.satelliteInfo.noradIndex,
                        julianDateRange: julianDateRange.roundJulianDate(.toMins(10)),
                        traitCollection: traitCollection
                    )
                )
            }
            .onChange(of: julianDateRange) { newJulianDateRange in
                if graphingRegionSize.width == 0 || graphingRegionSize.height == 0 {
                    return
                }

                let traitCollection = UITraitCollection(userInterfaceStyle: UIUserInterfaceStyle(colorScheme))

                viewModel.dispatch(
                    .requestRasterizeElevationGraph(
                        size: graphingRegionSize,
                        noradIndex: context.satelliteInfo.noradIndex,
                        julianDateRange: newJulianDateRange.roundJulianDate(.toMins(10)),
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
                    julianDateElevations: julianDateSunElevs
                )
            )
            .equatable()
            .frame(height: 24)
            .drawingGroup()

            julianDateRangePresent { julianDateRange in
                DateFooter(
                    state: DateFooterState(
                        julianDateRange: julianDateRange,
                        configs: context.configs
                    ),
                    width: rect.width
                )
                .equatable()
            }
        }
        .frame(
            width: max(0, rect.width),
            height: max(0, rect.height),
            alignment: .leading
        )
    }

    @ViewBuilder private func julianDateRangePresent<Content: View>(@ViewBuilder contentBuilder: (ClosedRange<Double>) -> Content) -> some View {
        if let julianDateRange = julianDateRange {
            contentBuilder(julianDateRange)
        } else {
            Color.clear
        }
    }

    var body: some View {
        julianDateRangePresent { julianDateRange in
            GeometryReader { geometry in
                let initialRect = geometry.frame(in: .local)
                let widthPerSecond = initialRect.width / CGFloat((julianDateRange.upperBound - julianDateRange.lowerBound) * TimeConstants.day2sec)
                let rect = CGRect(origin: initialRect.origin, size: CGSize(width: initialRect.width / widthPerSecond * max(widthPerSecond, context.configs.minimumHorizonalResolution), height: initialRect.height))

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
                                        if let _ = viewModel.state.highlightedDateRange {
                                            scrollViewProxy.scrollTo("centerAtDate", anchor: .center)
                                        }
                                    }
                                    .onChange(
                                        of: viewModel.state.highlightedDateRange,
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

extension ViewProducer where Context == SatelliteElevationGraphContext, ProducedView == SatelliteElevationGraph {
    static func satelliteElevationGraph<S: StoreType>(viewModel: S) -> ViewProducer where S.ActionType == AppAction, S.StateType == AppState {
        ViewProducer<Context, ProducedView> { context in
            SatelliteElevationGraph(
                viewModel: viewModel.projection(
                    action: AppAction.satelliteElevationGraph,
                    state:  SatelliteElevationGraphState.project(appState:)
                )
                .asObservableViewModel(initialState: .init(), emitsValue: .whenDifferent),
                context: context
            )
        }
    }
}

#if DEBUG
struct SatelliteElevationGraph_Previews: PreviewProvider {
    static var previews: some View {
        let elements = try! Elements(
            raw: """
            ISS (ZARYA)
            1 25544U 98067A   21152.11066515  .00000451  00000-0  16375-4 0  9992
            2 25544  51.6453  62.2423 0003364  52.3737  88.5313 15.48937685286109
            """
        )
        // Date range
        let julianDateRange = Date().advanced(by: -60 * 60 * 2).julianDate...Date().advanced(by: 60 * 60 * 4).julianDate
        // 2000 Broadway, Redwood City, CA 94063
        let location = CLLocation(latitude: 37.486743000691185, longitude: -122.22655970246515)
        let observer = LatLonAlt(location: location)
        let satelliteInfo = SatelliteInfo(elements: elements)
        let context = SatelliteElevationGraphContext(
            satelliteInfo: satelliteInfo,
            julianDateRange: julianDateRange,
            observer: observer,
            configs: .preset
        )
        let viewModel = SatelliteElevationGraphState.project(
            appState: AppState(
                navigationState: NavigationState(
                    listNavigation: ListNavigation(
                        noradIndex: elements.noradIndex
                    )
                ),
                satelliteTrails: [
                    elements.noradIndex: SatelliteTrails(
                        observer: observer,
                        snapshots: try! satelliteInfo.generateSnapshots(
                            observer: observer,
                            julianDateRange: julianDateRange,
                            interval: 20
                        )
                    )
                ],
                elementsLoader: ElementsLoaderResources(
                    info: [.brightest100: .loaded(
                        [elements.noradIndex: satelliteInfo]
                    )]
                ),
                locationState: LocationState(
                    authorizationStatus: .authorizedWhenInUse,
                    currentLocation: location
                )
            )
        )
        
        SatelliteElevationGraph(
            viewModel: .mock(state: viewModel),
            context: context
        )
        .environment(\.julianDateRangeKey, julianDateRange)
        .previewLayout(.fixed(width: 720, height: 240))
        .previewDisplayName("ISS")

        let elements2 = try! Elements(
            raw: """
            DFH-1
            1 04382U 70034A   21154.78159189  .00001370  00000-0  21022-3 0  9993
            2 04382  68.4187 192.6131 1052892 188.4862 169.7083 13.08082975404634
            """
        )
        let satelliteInfo2 = SatelliteInfo(elements: elements2)
        let context2 = SatelliteElevationGraphContext(
            satelliteInfo: satelliteInfo2,
            julianDateRange: julianDateRange,
            observer: observer,
            configs: .preset
        )
        let viewModel2 = SatelliteElevationGraphState.project(
            appState: AppState(
                navigationState: NavigationState(
                    listNavigation: ListNavigation(
                        noradIndex: elements2.noradIndex
                    )
                ),
                satelliteTrails: [
                    elements2.noradIndex: SatelliteTrails(
                        observer: observer,
                        snapshots: try! satelliteInfo2.generateSnapshots(
                            observer: observer,
                            julianDateRange: julianDateRange,
                            interval: 20
                        )
                    )
                ],
                elementsLoader: ElementsLoaderResources(
                    info: [.brightest100: .loaded(
                        [elements2.noradIndex: satelliteInfo2]
                    )]
                ),
                locationState: LocationState(
                    authorizationStatus: .authorizedWhenInUse,
                    currentLocation: location
                )
            )
        )
        SatelliteElevationGraph(viewModel: .mock(state: viewModel2), context: context2)
            .environment(\.julianDateRangeKey, julianDateRange)
            .previewLayout(.fixed(width: 720, height: 240))
            .previewDisplayName("DFH-1")

        let elements3 = try! Elements(
            raw: """
            MOLNIYA 2-9
            1 07276U 74026A   21154.36625011 -.00000128  00000-0  00000-0 0  9990
            2 07276  64.2122 283.1177 6670908 285.3565  14.2908  2.45094844240000
            """
        )
        let satelliteInfo3 = SatelliteInfo(elements: elements3)
        let context3 = SatelliteElevationGraphContext(
            satelliteInfo: satelliteInfo3,
            julianDateRange: julianDateRange,
            observer: observer,
            configs: .preset
        )
        let viewModel3 = SatelliteElevationGraphState.project(
            appState: AppState(
                navigationState: NavigationState(
                    listNavigation: ListNavigation(
                        noradIndex: elements3.noradIndex
                    )
                ),
                satelliteTrails: [
                    elements3.noradIndex: SatelliteTrails(
                        observer: observer,
                        snapshots: try! satelliteInfo3.generateSnapshots(
                            observer: observer,
                            julianDateRange: julianDateRange,
                            interval: 20
                        )
                    )
                ],
                elementsLoader: ElementsLoaderResources(
                    info: [.brightest100: .loaded(
                        [elements3.noradIndex: satelliteInfo3]
                    )]
                ),
                locationState: LocationState(
                    authorizationStatus: .authorizedWhenInUse,
                    currentLocation: location
                )
            )
        )
        SatelliteElevationGraph(viewModel: .mock(state: viewModel3), context: context3)
            .environment(\.julianDateRangeKey, julianDateRange)
            .previewLayout(.fixed(width: 720, height: 240))
            .previewDisplayName("Molniya 2-9")

    }
}
#endif
