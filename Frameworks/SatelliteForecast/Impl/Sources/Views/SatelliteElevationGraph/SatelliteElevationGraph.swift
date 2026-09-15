//
//  SatelliteElevationGraph.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 6/2/21.
//

import BTree
import SwiftUI
@preconcurrency import SatelliteKit
import SatelliteForecast
import CoreLocation

public struct SatelliteElevationGraphConfigs: Equatable, Sendable {
    public var timeGridLineInterval: TimeInterval = 30 * 60
    public var elevationGridLineInterval: Double = 30
    public var minimumHorizonalResolution: CGFloat = 3 / 60

    public init(timeGridLineInterval: TimeInterval = 30 * 60, elevationGridLineInterval: Double = 30, minimumHorizonalResolution: CGFloat = 3 / 60) {
        self.timeGridLineInterval = timeGridLineInterval
        self.elevationGridLineInterval = elevationGridLineInterval
        self.minimumHorizonalResolution = minimumHorizonalResolution
    }
}

public struct SatelliteElevationGraphContext {
    public let satelliteInfo: SatelliteInfo
    public let selectedPassIndex: Int
    public let selectedPass: Pass?
    public let julianDateRange: ClosedRange<Double>
    public let observer: LatLonAlt
    public let configs: SatelliteElevationGraphConfigs
    /// Because we are showing a time window of satellite elevations, as time ticks every few seconds,
    /// the time window of the satellite elevations (usually spanning a few days) shifts forward by that amount of seconds.
    /// To prevent generating graph at a high frequency, this time is time spent before generating a new elevation graph.
    public let elevationGraphTolerance: Double = TimeConstants.min2day
    public let julianDateProvider: () -> Double

    public var noradIndex: UInt {
        return satelliteInfo.noradIndex
    }

    public init(
        satelliteInfo: SatelliteInfo,
        selectedPassIndex: Int,
        julianDateRange: ClosedRange<Double>,
        observer: LatLonAlt,
        configs: SatelliteElevationGraphConfigs,
        julianDateProvider: @escaping () -> Double,
        selectedPass: Pass? = nil
    ) {
        self.selectedPass = selectedPass
        self.satelliteInfo = satelliteInfo
        self.selectedPassIndex = selectedPassIndex
        self.julianDateRange = julianDateRange
        self.observer = observer
        self.configs = configs
        self.julianDateProvider = julianDateProvider
    }
}

public struct SatelliteElevationGraphState: Equatable {
    public var satelliteElevationGraphResources: SatelliteElevationGraphResources = .init()
    public var elementsPropagatorResources: ElementsPropagatorResources = .init()
    public var julianDateOffset: Double = 0

    public init(
        satelliteElevationGraphResources: SatelliteElevationGraphResources = .init(),
        elementsPropagatorResources: ElementsPropagatorResources = .init(),
        julianDateOffset: Double = 0
    ) {
        self.satelliteElevationGraphResources = satelliteElevationGraphResources
        self.elementsPropagatorResources = elementsPropagatorResources
        self.julianDateOffset = julianDateOffset
    }
}

public struct SatelliteElevationGraph: View {
    @State var viewModel: ElevationGraphModel
    let context: SatelliteElevationGraphContext

    @State private var graphingRegionSize: CGSize = .zero
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.julianDateRangeKey) var julianDateRange

    struct PercentDate: Equatable {
        let percent: Double
        let julianDate: Double
    }

    public init(
        viewModel: ElevationGraphModel,
        context: SatelliteElevationGraphContext
    ) {
        self.viewModel = viewModel
        self.context = context
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

    var currentJulianDate: Double {
        context.julianDateProvider() + viewModel.state.julianDateOffset
    }

    var currentSnapshot: SatelliteSnapshot {
        try! context.satelliteInfo.generateSnapshot(
            julianDate: currentJulianDate,
            observer: context.observer
        )
    }

    private var selectedSatellitePass: Pass? {
        if let pass = context.selectedPass { return pass }
        guard let passes = viewModel.state.elementsPropagatorResources.satelliteTrails[context.noradIndex]?.passSnapshots,
              passes.indices.contains(context.selectedPassIndex) else { return nil }
        return passes[context.selectedPassIndex].pass
    }

    private var highlightedDateRange: ClosedRange<Double>? {
        return selectedSatellitePass.map { pass -> ClosedRange<Double> in
            return pass.rise.julianDate...pass.set.julianDate
        }
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
                if let highlightedDateRange = highlightedDateRange {
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
            let _ = viewModel.state
            let x = (currentJulianDate - julianDateRange.lowerBound) / (julianDateRange.upperBound - julianDateRange.lowerBound)
            let y = 1 - (currentSnapshot.position.elev + 90) / 180

            SatelliteElevationGraphCurrentIndicator(
                percentageCoordinate: CGPoint(x: x, y: y),
                currentJulianDate: currentJulianDate
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
            .onChange(of: graphingRegionSize) { _, size in
                if size.width == 0 || size.height == 0 {
                    return
                }

                let traitCollection = UITraitCollection(userInterfaceStyle: UIUserInterfaceStyle(colorScheme))

                viewModel.send(
                    .requestRasterizeElevationGraph(
                        size: size,
                        noradIndex: context.satelliteInfo.noradIndex,
                        julianDateRange: julianDateRange.roundJulianDate(.toMins(10)),
                        traitCollection: traitCollection
                    )
                )
            }
            .onChange(of: julianDateRange) { _, newJulianDateRange in
                if graphingRegionSize.width == 0 || graphingRegionSize.height == 0 {
                    return
                }

                let traitCollection = UITraitCollection(userInterfaceStyle: UIUserInterfaceStyle(colorScheme))

                viewModel.send(
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

    public var body: some View {
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
                                        if let _ = highlightedDateRange {
                                            scrollViewProxy.scrollTo("centerAtDate", anchor: .center)
                                        }
                                    }
                                    .onChange(
                                        of: highlightedDateRange
                                    ) {
                                        scrollViewProxy.scrollTo("centerAtDate", anchor: .center)
                                    }
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
