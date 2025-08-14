//
//  SkyChart.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 5/30/21.
//

@preconcurrency import CombineRex
@preconcurrency import CombineRextensions
import SwiftUI
import SwiftUIVisualEffects
@preconcurrency import SatelliteKit
import SatelliteForecast
import StarryNight
@preconcurrency import CombineRextensions
import BTree
import CoreMotion

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

public struct SkyChart<ConstellationLabel: View, BackgroundAnnotationView: View>: View {
    @ObservedObject var viewModel: ObservableViewModel<SkyChartAction, SkyChartViewState>
    let context: SkyChartContext<ConstellationLabel, BackgroundAnnotationView>
    let backgroundSkyViewProducer: ViewProducer<BackgroundSkyViewContext<ConstellationLabel, BackgroundAnnotationView>, BackgroundSkyView<ConstellationLabel, BackgroundAnnotationView>>

    @State private var contentSize: CGSize = .zero

    @State var refreshTimer = Timer.publish(
        every: 10,
        on: .main,
        in: .common
    )
    .autoconnect()
    .map(\.julianDate)

    @State var backgroundSkyJulianDateKey: Double?

    @Environment(\.colorScheme) var colorScheme

    private func propagateBackgroundSkyJulianDateKey(_ julianDate: Double) {
        if (context.passSnapshots.pass.rise.julianDate..<context.passSnapshots.pass.set.julianDate).contains(julianDate) {
            backgroundSkyJulianDateKey = julianDate.roundJulianDate(.toMins(1))
        }
        backgroundSkyJulianDateKey = context.passSnapshots.pass.rise.julianDate.roundJulianDate(.toMins(1))
    }
    public init(
        viewModel: ObservableViewModel<SkyChartAction, SkyChartViewState>,
        context: SkyChartContext<ConstellationLabel, BackgroundAnnotationView>,
        backgroundSkyViewProducer: ViewProducer<BackgroundSkyViewContext<ConstellationLabel, BackgroundAnnotationView>, BackgroundSkyView<ConstellationLabel, BackgroundAnnotationView>>
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
                    // Rise label
                    SkyChartPassLabel(
                        snapshotPair: context.passSnapshots.notableSnapshots.rise,
                        rect: rect,
                        modifierFactory: PassLabelModifier.init(rotationAngle:)
                    ) {
                        Text(
                            """
                            ↑ \(SkyChartUtils.labelDateFormatter.string(from: Date(julianDate: context.passSnapshots.pass.rise.julianDate)))
                            """
                        )
                    }

                    // Set label
                    SkyChartPassLabel(
                        snapshotPair: context.passSnapshots.notableSnapshots.set,
                        rect: rect,
                        modifierFactory: PassLabelModifier.init(rotationAngle:)
                    ) {
                        Text(
                            """
                            ↓ \(SkyChartUtils.labelDateFormatter.string(from: Date(julianDate: context.passSnapshots.pass.set.julianDate)))
                            """
                        )
                    }

                    // Transit label
                    SkyChartPassLabel(
                        snapshotPair: context.passSnapshots.notableSnapshots.transit,
                        rect: rect,
                        modifierFactory: PassLabelModifier.init(rotationAngle:)
                    ) {
                        Text(
                            """
                            ∠\(SkyChartUtils.labelAngleFormatter.string(from: NSNumber(value: context.passSnapshots.pass.culmination.elev))!)° \(SkyChartUtils.labelDateFormatter.string(from: Date(julianDate: context.passSnapshots.pass.culmination.julianDate)))
                            """
                        )
                    }

                    // Illumination change labels
                    ForEach(context.passSnapshots.notableSnapshots.illuminationChanges, id: \.change.datePosition) { illuminationChanges in
                        SkyChartPassLabel(
                            snapshotPair: illuminationChanges.snapshots,
                            rect: rect,
                            modifierFactory: PassLabelModifier.init(rotationAngle:)
                        ) {
                            Text(
                                SkyChartPassLabel<PassLabelModifier, Text>.textForIlluminationChange(
                                    illuminationChanges.change,
                                    dateFormatter: SkyChartUtils.labelDateFormatter
                                )
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
        case .detailed:
            return viewModel.state.resources.detailedSatellitePaths[context.passSnapshots.pass]
        case .full:
            return viewModel.state.resources.rasterizedSatellitePaths[context.passSnapshots.pass]
        case .preview:
            return viewModel.state.resources.previewSatellitePaths[context.passSnapshots.pass]
        case .onboarding:
            return viewModel.state.resources.onboardingSatellitePaths[context.passSnapshots.pass]
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
                        passSnapshots: context.passSnapshots,
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
                quality: context.quality,
                starManager: context.starManager,
                constellationLabel: context.constellationLabel,
                annotationView: context.backgroundAnnotationView,
                starTapped: context.backgroundStarTapped
            )
        )
        .environment(\.backgroundSkyJulianDateKey, backgroundSkyJulianDateKey)
        .background(
            satellitePath.overlay(loadingIndicator)
            .clipShape(Circle())
        )
        .overlay(passInfoLabels)
        .overlay(
            SkyChartDynamicIndicator(
                state: SkyChartDynamicIndicatorState(
                    satelliteInfo: context.satelliteInfo,
                    pass: context.passSnapshots.pass,
                    observer: context.observer,
                    julianDateOffset: viewModel.state.julianDateOffset
                )
            ).clipShape(Circle())
        )
        .onLoad {
            propagateBackgroundSkyJulianDateKey(context.julianDateProvider() + viewModel.state.julianDateOffset)
        }
        .onReceive(refreshTimer) { julianDate in
            propagateBackgroundSkyJulianDateKey(julianDate + viewModel.state.julianDateOffset)
        }
    }
}

public struct SkyChartContext<ConstellationLabel: View, BackgroundAnnotationView: View> {
    public let satelliteInfo: SatelliteInfo
    public let observer: LatLonAlt
    public let passSnapshots: PassSnapshots
    public let configs: SkyChartConfigs
    public let quality: ChartQuality
    public let starManager: any StarManaging
    public let julianDateProvider: () -> Double
    public let deviceMotion: Loadable<CMDeviceMotion, Error>
    @ViewBuilder public let constellationLabel: (String) -> ConstellationLabel
    @ViewBuilder public let backgroundAnnotationView: (@escaping (RADec) -> CGPoint) -> BackgroundAnnotationView
    public let backgroundStarTapped: (Star?) -> Void

    public init(
        satelliteInfo: SatelliteInfo,
        observer: LatLonAlt,
        passSnapshots: PassSnapshots,
        configs: SkyChartConfigs,
        quality: ChartQuality,
        starManager: any StarManaging,
        julianDateProvider: @escaping () -> Double,
        deviceMotion: Loadable<CMDeviceMotion, Error> = .notLoaded,
        @ViewBuilder constellationLabel: @escaping (String) -> ConstellationLabel,
        @ViewBuilder backgroundAnnotationView: @escaping (@escaping (RADec) -> CGPoint) -> BackgroundAnnotationView,
        backgroundStarTapped: @escaping (Star?) -> Void = { _ in }
    ) {
        self.satelliteInfo = satelliteInfo
        self.observer = observer
        self.passSnapshots = passSnapshots
        self.configs = configs
        self.quality = quality
        self.starManager = starManager
        self.julianDateProvider = julianDateProvider
        self.deviceMotion = deviceMotion
        self.constellationLabel = constellationLabel
        self.backgroundAnnotationView = backgroundAnnotationView
        self.backgroundStarTapped = backgroundStarTapped
    }
}

extension SkyChartContext where ConstellationLabel == EmptyView, BackgroundAnnotationView == EmptyView {
    public init(
        satelliteInfo: SatelliteInfo,
        observer: LatLonAlt,
        passSnapshots: PassSnapshots,
        configs: SkyChartConfigs,
        quality: ChartQuality,
        starManager: any StarManaging,
        julianDateProvider: @escaping () -> Double,
        deviceMotion: Loadable<CMDeviceMotion, Error> = .notLoaded,
        backgroundStarTapped: @escaping (Star?) -> Void = { _ in }
    ) {
        self.satelliteInfo = satelliteInfo
        self.observer = observer
        self.passSnapshots = passSnapshots
        self.configs = configs
        self.quality = quality
        self.starManager = starManager
        self.julianDateProvider = julianDateProvider
        self.deviceMotion = deviceMotion
        self.constellationLabel = { _ in EmptyView() }
        self.backgroundAnnotationView = { _ in EmptyView() }
        self.backgroundStarTapped = backgroundStarTapped
    }
}

extension SkyChartPassLabel {
    static func textForIlluminationChange(
        _ change: Pass.Illumination.Change,
        dateFormatter: DateFormatter
    ) -> String {
        switch change {
        case let .entersShadow(datePosition):
            let format = NSLocalizedString(
                "SkyChartPassLabel.text.illuminationChange.entersShadow",
                tableName: nil,
                bundle: .module,
                value: """
                    Enters shadow
                    %@
                    """,
                comment: "The pass label format text of an illumination change: enters shadow"
            )
            return String(format: format, dateFormatter.string(from: Date(julianDate: datePosition.julianDate)))
        case let .exitsShadow(datePosition):
            let format = NSLocalizedString(
                "SkyChartPassLabel.text.illuminationChange.exitsShadow",
                tableName: nil,
                bundle: .module,
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
        let satelliteInfo = try! SatelliteInfo(elements: elements)
        let observer = LatLonAlt(32.0669, 118.8251, 0)
        let snapshots = try! satelliteInfo.generateSnapshots(
            observer: observer,
            julianDateRange: date.julianDate...date.addingTimeInterval(800).julianDate
        )

        let passSnapshots = try! satelliteInfo.findPasses(
            observer: LatLonAlt(32.0669, 118.8251, 0),
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
        let satelliteInfo = try! SatelliteInfo(elements: elements)
        let observer = LatLonAlt(-27.1570, -109.4274, 0)
        let snapshots = try! satelliteInfo.generateSnapshots(
            observer: observer,
            julianDateRange: date.julianDate...date.addingTimeInterval(800).julianDate
        )

        let passSnapshots = try! satelliteInfo.findPasses(
            observer: LatLonAlt(-27.1570, -109.4274, 0),
            coarseSnapshots: snapshots
        )
        let firstPassSnapshots = passSnapshots.first!
        return (elements, firstPassSnapshots)
    }()

    static var previews: some View {
        let (elements, passSnapshots) = issPass

        ForEach(ColorScheme.allCases, id: \.self) { colorScheme in
            let traitCollection = UITraitCollection(userInterfaceStyle: UIUserInterfaceStyle(colorScheme))
            let referenceDate = passSnapshots.pass.culmination.julianDate.advanced(by: 20 * TimeConstants.sec2day)
            SkyChart<EmptyView, EmptyView>(
                viewModel: .mock(
                    state: SkyChartViewState(
                        resources: SkyChartResources(
                            rasterizedSatellitePaths: [
                                passSnapshots.pass: SkyChartUtils.rasterizedSatellitePassPath(
                                    params: SatellitePassPathRenderParams(
                                        rect: CGRect(origin: .zero, size: CGSize(width: 388, height: 805)),
                                        snapshotsDuringPass: passSnapshots.snapshots,
                                        illuminatedColor: UIColor(
                                            named: "satellitePath_illuminated",
                                            in: .module,
                                            compatibleWith: traitCollection
                                        )!,
                                        unlitColor: UIColor(
                                            named: "satellitePath_notIlluminated",
                                            in: .module,
                                            compatibleWith: traitCollection
                                        )!
                                    )
                                )
                            ],
                            previewSatellitePaths: [:]
                        )
                    )
                ),
                context: SkyChartContext(
                    satelliteInfo: try! SatelliteInfo(elements: elements),
                    observer: LatLonAlt(32.0669, 118.8251, 0),
                    passSnapshots: passSnapshots,
                    configs: .preset,
                    quality: .full,
                    starManager: StarManagerMock(),
                    julianDateProvider: { referenceDate }
                ),
                backgroundSkyViewProducer: .pure(
                    BackgroundSkyView(
                        viewModel: .mock(
                            state: BackgroundSkyViewState()
                        ),
                        context: BackgroundSkyViewContext(
                            observer: LatLonAlt(32.0669, 118.8251, 0),
                            basicChartConfigs: .init(),
                            configs: .init(),
                            quality: .full,
                            starManager: StarManagerMock(),
                            constellationLabel: { _ in EmptyView() },
                            annotationView: { _ in EmptyView() },
                            starTapped: { _ in }
                        )
                    )
                )
            )
            .padding(20)
            .preferredColorScheme(colorScheme)
            .environment(\.backgroundSkyJulianDateKey, referenceDate.roundJulianDate(.toMins(1)))
        }

        let (elements2, passSnapshots2) = tianHePass

        SkyChart<EmptyView, EmptyView>(
            viewModel: .mock(
                state: SkyChartViewState(
                    resources: SkyChartResources(
                        rasterizedSatellitePaths: [
                            passSnapshots2.pass: SkyChartUtils.rasterizedSatellitePassPath(
                                params: SatellitePassPathRenderParams(
                                    rect: CGRect(origin: .zero, size: CGSize(width: 388, height: 805)),
                                    snapshotsDuringPass: passSnapshots2.snapshots,
                                    illuminatedColor: UIColor(Color("satellitePath_illuminated", bundle: .module)),
                                    unlitColor: UIColor(Color("satellitePath_notIlluminated", bundle: .module))
                                )
                            )
                        ],
                        previewSatellitePaths: [:]
                    )
                )
            ),
            context: SkyChartContext(
                satelliteInfo: try! SatelliteInfo(elements: elements2),
                observer: LatLonAlt(-27.1570, -109.4274, 0),
                passSnapshots: passSnapshots2,
                configs: .preset,
                quality: .full,
                starManager: StarManagerMock(),
                julianDateProvider: { passSnapshots2.pass.rise.julianDate }
            ),
            backgroundSkyViewProducer: .pure(
                BackgroundSkyView(
                    viewModel: .mock(
                        state: BackgroundSkyViewState()
                    ),
                    context: BackgroundSkyViewContext(
                        observer: LatLonAlt(-27.1570, -109.4274, 0),
                        basicChartConfigs: .init(),
                        configs: .preset,
                        quality: .full,
                        starManager: StarManagerMock(),
                        constellationLabel: { _ in EmptyView() },
                        annotationView: { _ in EmptyView() },
                        starTapped: { _ in }
                    )
                )
            )
        )
        .padding(20)
        .environment(\.backgroundSkyJulianDateKey, passSnapshots2.pass.rise.julianDate.roundJulianDate(.toMins(1)))

        SkyChart<EmptyView, EmptyView>(
            viewModel: .mock(state: .init()),
            context: SkyChartContext(
                satelliteInfo: try! SatelliteInfo(elements: elements2),
                observer: LatLonAlt(-27.1570, -109.4274, 0),
                passSnapshots: passSnapshots2,
                configs: .preset,
                quality: .full,
                starManager: StarManagerMock(),
                julianDateProvider: { passSnapshots2.pass.rise.julianDate }
            ),
            backgroundSkyViewProducer: .pure(
                BackgroundSkyView(
                    viewModel: .mock(
                        state: BackgroundSkyViewState()
                    ),
                    context: BackgroundSkyViewContext(
                        observer: LatLonAlt(-27.1570, -109.4274, 0),
                        basicChartConfigs: .init(),
                        configs: .preset,
                        quality: .full,
                        starManager: StarManagerMock(),
                        constellationLabel: { _ in EmptyView() },
                        annotationView: { _ in EmptyView() },
                        starTapped: { _ in }
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
