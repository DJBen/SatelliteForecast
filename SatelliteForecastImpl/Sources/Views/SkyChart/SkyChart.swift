//
//  SkyChart.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 5/30/21.
//

import CombineRex
import CombineRextensions
import SwiftUI
import SwiftUIVisualEffects
import SatelliteKit
import SatelliteForecast
import StarryNight
import CombineRextensions
import BTree

public enum SkyChartAction {
    case requestRasterizedSatellitePath(size: CGSize, quality: ChartQuality, pass: Pass, traitCollection: UITraitCollection)
}

extension SkyChartAction: Equatable {}

public enum SkyChartOutput {
    /// A satellite path is rasterized, or the rasterized image is read from the cache.
    case rasterizedSatellitePath(UIImage, quality: ChartQuality, pass: Pass)
}

/// A state used in a single sky chart view
public struct SkyChartViewState: Equatable {
    /// The julian date offset between the julian date in display and the actual julian date.
    /// This property is being used by the dynamic label
    public var julianDateOffset: Double = 0
    public var resources: SkyChartResources = .init()
    public var backgroundSky: BackgroundSkyResources = .init()
    public var elementsPropagatorResources: ElementsPropagatorResources = .init()

    public init(
        julianDateOffset: Double = 0,
        resources: SkyChartResources = .init(),
        backgroundSky: BackgroundSkyResources = .init(),
        elementsPropagatorResources: ElementsPropagatorResources = .init()
    ) {
        self.julianDateOffset = julianDateOffset
        self.resources = resources
        self.backgroundSky = backgroundSky
        self.elementsPropagatorResources = elementsPropagatorResources
    }
}

public struct SkyChart: View {
    @ObservedObject var viewModel: ObservableViewModel<SkyChartAction, SkyChartViewState>
    let context: SkyChartContext
    let backgroundSkyViewProducer: ViewProducer<BackgroundSkyViewContext, BackgroundSkyView>

    @State private var contentSize: CGSize = .zero

    let refreshTimer = Timer.publish(
        every: 10,
        on: .main,
        in: .common
    )
        .autoconnect()
        .map(\.julianDate)

    @State var backgroundSkyJulianDateKey: Double?

    @Environment(\.colorScheme) var colorScheme

    private func propagateBackgroundSkyJulianDateKey(_ julianDate: Double) {
        if (context.pass.rise.julianDate..<context.pass.set.julianDate).contains(julianDate) {
            backgroundSkyJulianDateKey = julianDate.roundJulianDate(.toMins(1))
        }
        backgroundSkyJulianDateKey = context.pass.rise.julianDate.roundJulianDate(.toMins(1))
    }
    public init(
        viewModel: ObservableViewModel<SkyChartAction, SkyChartViewState>,
        context: SkyChartContext,
        backgroundSkyViewProducer: ViewProducer<BackgroundSkyViewContext, BackgroundSkyView>
    ) {
        self.viewModel = viewModel
        self.context = context
        self.backgroundSkyViewProducer = backgroundSkyViewProducer
    }

    @ViewBuilder private var passInfoLabels: some View {
        if context.configs.showPassInfoLabels {
            GeometryReader { geometry in
                let rect = geometry.frame(in: .local)

                ZStack {
                    PassLabel(
                        text: "↑ \(Self.labelDateFormatter.string(from: Date(julianDate: context.pass.rise.julianDate)))",
                        snapshotPair: context.notableSnapshots.rise,
                        rect: rect,
                        modifierFactory: PassLabelModifier.init(rotationAngle:)
                    )

                    PassLabel(
                        text: "↓ \(Self.labelDateFormatter.string(from: Date(julianDate: context.pass.set.julianDate)))",
                        snapshotPair: context.notableSnapshots.set,
                        rect: rect,
                        modifierFactory: PassLabelModifier.init(rotationAngle:)
                    )

                    PassLabel(
                        text: "∠\(Self.labelAngleFormatter.string(from: NSNumber(value: context.pass.transit.elev))!)° \(Self.labelDateFormatter.string(from: Date(julianDate: context.pass.transit.julianDate)))",
                        snapshotPair: context.notableSnapshots.transit,
                        rect: rect,
                        modifierFactory: PassLabelModifier.init(rotationAngle:)
                    )

                    ForEach(context.pass.illumination.changes, id: \.datePosition) { change in
                        if let illuminationChangeAndSnapshots = context.notableSnapshots.illuminationChanges.value(of: change.datePosition.julianDate) {
                            PassLabel(
                                text: SkyChart.PassLabel<PassLabelModifier>.textForIlluminationChange(
                                    change,
                                    dateFormatter: Self.labelDateFormatter
                                ),
                                snapshotPair: illuminationChangeAndSnapshots.snapshots,
                                rect: rect,
                                modifierFactory: PassLabelModifier.init(rotationAngle:)
                            )
                        }
                    }
                }
                .blurEffectStyle(colorScheme == .light ? .systemMaterialDark : .systemMaterialLight)
                .vibrancyEffectStyle(.fill)
            }
        }
    }

    private var rasterizedSatellitePath: UIImage? {
        switch context.quality {
        case .full:
            return viewModel.state.resources.rasterizedSatellitePaths[context.pass]
        case .preview:
            return viewModel.state.resources.previewSatellitePaths[context.pass]
        }
    }

    @ViewBuilder private var satellitePath: some View {
        GeometryReader { geometry in
            let rect = geometry.frame(in: .local)
            Group {
                if rect.size.width == 0 || rect.size.height == 0 {
                    Color.clear
                } else if let image = rasterizedSatellitePath {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: rect.width, height: rect.height, alignment: .center)
                } else {
                    Color.clear
                }
            }
            .modifier(SizeModifier())
            .onPreferenceChange(SizePreferenceKey.self) { contentSize in

                guard !contentSize.width.isZero && !contentSize.height.isZero else {
                    return
                }

                self.contentSize = contentSize

                viewModel.dispatch(
                    .requestRasterizedSatellitePath(
                        size: contentSize,
                        quality: context.quality,
                        pass: context.pass,
                        traitCollection: UITraitCollection(userInterfaceStyle: UIUserInterfaceStyle(colorScheme))
                    )
                )
            }
        }
    }

    @ViewBuilder var loadingIndicator: some View {
        if rasterizedSatellitePath == nil {
            ProgressView()
        }
    }

    public var body: some View {
        backgroundSkyViewProducer.view(
            BackgroundSkyViewContext(
                observer: context.observer,
                basicChartConfigs: context.configs.basicChartConfigs,
                configs: context.configs.backgroundSkyConfigs,
                quality: context.quality
            )
        )
        .environment(\.backgroundSkyJulianDateKey, backgroundSkyJulianDateKey)
        .overlay(passInfoLabels)
        .overlay(
            SkyChartDynamicIndicator(
                state: SkyChartDynamicIndicatorState(
                    satelliteInfo: context.satelliteInfo,
                    pass: context.pass,
                    observer: context.observer,
                    julianDateOffset: viewModel.state.julianDateOffset
                )
            ).clipShape(Circle())
        )
        .background(
            satellitePath.overlay(loadingIndicator)
            .clipShape(Circle())
        )
        .onLoad {
            propagateBackgroundSkyJulianDateKey(context.julianDateProvider() + viewModel.state.julianDateOffset)
        }
        .onReceive(refreshTimer) { julianDate in
            propagateBackgroundSkyJulianDateKey(julianDate + viewModel.state.julianDateOffset)
        }
    }
}

public struct SkyChartContext {
    public let satelliteInfo: SatelliteInfo
    public let snapshots: [SatelliteSnapshot]
    public let observer: LatLonAlt
    public let pass: Pass
    public let notableSnapshots: NotableSnapshots
    public let configs: SkyChartConfigs
    public let quality: ChartQuality
    public let julianDateProvider: () -> Double
}

extension SkyChart.PassLabel {
    static func textForIlluminationChange(
        _ change: Pass.Illumination.Change,
        dateFormatter: DateFormatter
    ) -> String {
        switch change {
        case let .entersShadow(datePosition):
            let format = NSLocalizedString(
                "SkyChart.PassLabel.text.illuminationChange.entersShadow",
                tableName: nil,
                bundle: .main,
                value: """
                    Enters shadow
                    %@
                    """,
                comment: "The pass label format text of an illumination change: enters shadow"
            )
            return String(format: format, dateFormatter.string(from: Date(julianDate: datePosition.julianDate)))
        case let .exitsShadow(datePosition):
            let format = NSLocalizedString(
                "SkyChart.PassLabel.text.illuminationChange.exitsShadow",
                tableName: nil,
                bundle: .main,
                value: """
                    Exits shadow
                    %@
                    """,
                comment: "The pass label format text of an illumination change: exits shadow"
            )
            return String(format: format, dateFormatter.string(from: Date(julianDate: datePosition.julianDate)))
        }
    }
}

#if DEBUG
struct SkyChart_Previews: PreviewProvider {
    static let issPass: (Elements, PassSnapshots) = {
        let elements = try! Elements(
            raw: """
            ISS (ZARYA)
            1 25544U 98067A   21152.11066515  .00000451  00000-0  16375-4 0  9992
            2 25544  51.6453  62.2423 0003364  52.3737  88.5313 15.48937685286109
            """
        )

        let formatter = ISO8601DateFormatter()
        let date = formatter.date(from: "2021-06-02T20:35:30+0800")!
        let satelliteInfo = SatelliteInfo(elements: elements)
        let observer = LatLonAlt(lat: 32.0669, lon: 118.8251, alt: 0)
        let snapshots = try! satelliteInfo.generateSnapshots(
            observer: observer,
            julianDateRange: date.julianDate...date.addingTimeInterval(800).julianDate
        )

        let passSnapshots = try! satelliteInfo.findPasses(
            observer: LatLonAlt(lat: 32.0669, lon: 118.8251, alt: 0),
            coarseSnapshots: snapshots
        )
        let firstPassSnapshots = passSnapshots.first!
        return (elements, firstPassSnapshots)
    }()

    static let tianHePass: (Elements, PassSnapshots) = {
        let elements = try! Elements(
            raw: """
            TIANHE
            1 48274U 21035A   21152.91865056  .00003057  00000-0  33542-4 0  9993
            2 48274  41.4713  16.3199 0005053  25.9394 109.3813 15.65195495  5304
            """
        )

        let formatter = ISO8601DateFormatter()
        let date = formatter.date(from: "2021-06-02T06:29:00-0600")!
        let satelliteInfo = SatelliteInfo(elements: elements)
        let observer = LatLonAlt(lat: -27.1570, lon: -109.4274, alt: 0)
        let snapshots = try! satelliteInfo.generateSnapshots(
            observer: observer,
            julianDateRange: date.julianDate...date.addingTimeInterval(800).julianDate
        )

        let passSnapshots = try! satelliteInfo.findPasses(
            observer: LatLonAlt(lat: -27.1570, lon: -109.4274, alt: 0),
            coarseSnapshots: snapshots
        )
        let firstPassSnapshots = passSnapshots.first!
        return (elements, firstPassSnapshots)
    }()

    static var previews: some View {
        let (elements, passSnapshots) = issPass

        ForEach(ColorScheme.allCases, id: \.self) { colorScheme in
            let traitCollection = UITraitCollection(userInterfaceStyle: UIUserInterfaceStyle(colorScheme))
            let referenceDate = passSnapshots.pass.transit.julianDate.advanced(by: 20 * TimeConstants.sec2day)
            SkyChart(
                viewModel: .mock(
                    state: SkyChartViewState(
                        resources: SkyChartResources(
                            rasterizedSatellitePaths: [
                                passSnapshots.pass: SkyChart.rasterizedSatellitePassPath(
                                    params: SatellitePassPathRenderParams(
                                        rect: CGRect(origin: .zero, size: CGSize(width: 388, height: 805)),
                                        snapshotsDuringPass: passSnapshots.snapshots,
                                        illuminatedColor: UIColor(named: "satellitePath_illuminated", in: nil, compatibleWith: traitCollection)!,
                                        unlitColor: UIColor(named: "satellitePath_notIlluminated", in: nil, compatibleWith: traitCollection)!
                                    )
                                )
                            ],
                            previewSatellitePaths: [:]
                        )
                    )
                ),
                context: SkyChartContext(
                    satelliteInfo: SatelliteInfo(elements: elements),
                    snapshots: passSnapshots.snapshots,
                    observer: LatLonAlt(lat: 32.0669, lon: 118.8251, alt: 0),
                    pass: passSnapshots.pass,
                    notableSnapshots: passSnapshots.notableSnapshots,
                    configs: .preset,
                    quality: .full,
                    julianDateProvider: { referenceDate }
                ),
                backgroundSkyViewProducer: .pure(
                    BackgroundSkyView(
                        viewModel: .mock(
                            state: BackgroundSkyViewState()
                        ),
                        context: BackgroundSkyViewContext(
                            observer: LatLonAlt(lat: 32.0669, lon: 118.8251, alt: 0),
                            basicChartConfigs: .init(),
                            configs: .init(),
                            quality: .full
                        )
                    )
                )
            )
            .padding(20)
            .preferredColorScheme(colorScheme)
            .environment(\.backgroundSkyJulianDateKey, referenceDate.roundJulianDate(.toMins(1)))
        }

        let (elements2, passSnapshots2) = tianHePass

        SkyChart(
            viewModel: .mock(
                state: SkyChartViewState(
                    resources: SkyChartResources(
                        rasterizedSatellitePaths: [
                            passSnapshots2.pass: SkyChart.rasterizedSatellitePassPath(
                                params: SatellitePassPathRenderParams(
                                    rect: CGRect(origin: .zero, size: CGSize(width: 388, height: 805)),
                                    snapshotsDuringPass: passSnapshots2.snapshots,
                                    illuminatedColor: UIColor(Color("satellitePath_illuminated", bundle: .satelliteForecastImplResourcesBundle)),
                                    unlitColor: UIColor(Color("satellitePath_notIlluminated", bundle: .satelliteForecastImplResourcesBundle))
                                )
                            )
                        ],
                        previewSatellitePaths: [:]
                    )
                )
            ),
            context: SkyChartContext(
                satelliteInfo: SatelliteInfo(elements: elements2),
                snapshots: passSnapshots2.snapshots,
                observer: LatLonAlt(lat: -27.1570, lon: -109.4274, alt: 0),
                pass: passSnapshots2.pass,
                notableSnapshots: passSnapshots2.notableSnapshots,
                configs: .preset,
                quality: .full,
                julianDateProvider: { passSnapshots2.pass.rise.julianDate }
            ),
            backgroundSkyViewProducer: .pure(
                BackgroundSkyView(
                    viewModel: .mock(
                        state: BackgroundSkyViewState()
                    ),
                    context: BackgroundSkyViewContext(
                        observer: LatLonAlt(lat: -27.1570, lon: -109.4274, alt: 0),
                        basicChartConfigs: .init(),
                        configs: .preset,
                        quality: .full
                    )
                )
            )
        )
        .padding(20)
        .environment(\.backgroundSkyJulianDateKey, passSnapshots2.pass.rise.julianDate.roundJulianDate(.toMins(1)))

        SkyChart(
            viewModel: .mock(state: .init()),
            context: SkyChartContext(
                satelliteInfo: SatelliteInfo(elements: elements2),
                snapshots: passSnapshots2.snapshots,
                observer: LatLonAlt(lat: -27.1570, lon: -109.4274, alt: 0),
                pass: passSnapshots2.pass,
                notableSnapshots: passSnapshots2.notableSnapshots,
                configs: .preset,
                quality: .full,
                julianDateProvider: { passSnapshots2.pass.rise.julianDate }
            ),
            backgroundSkyViewProducer: .pure(
                BackgroundSkyView(
                    viewModel: .mock(
                        state: BackgroundSkyViewState()
                    ),
                    context: BackgroundSkyViewContext(
                        observer: LatLonAlt(lat: -27.1570, lon: -109.4274, alt: 0),
                        basicChartConfigs: .init(),
                        configs: .preset,
                        quality: .full
                    )
                )
            )
        )
        .padding(20)
        .previewDisplayName("Placeholder")
        .environment(\.backgroundSkyJulianDateKey, passSnapshots2.pass.rise.julianDate.roundJulianDate(.toMins(1)))
    }
}
#endif
