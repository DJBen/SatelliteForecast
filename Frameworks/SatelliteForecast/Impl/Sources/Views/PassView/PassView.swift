//
//  PassView.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 6/5/21.
//

import BTree
import SatelliteForecast
@preconcurrency import SatelliteKit
import SwiftUI
import SwiftUIVisualEffects
import StarryNight
import CoreMotion

public struct PassViewState {
    public var scheduledPassNotifications: Set<ScheduledPassNotification>
    public var showAlarmConfigurationModal: Bool
    public var showsDetailPassView: Bool

    public init(
        scheduledPassNotifications: Set<ScheduledPassNotification> = [],
        showAlarmConfigurationModal: Bool = false,
        showsDetailPassView: Bool = false
    ) {
        self.scheduledPassNotifications = scheduledPassNotifications
        self.showAlarmConfigurationModal = showAlarmConfigurationModal
        self.showsDetailPassView = showsDetailPassView
    }
}

extension PassViewState: Equatable {}

/// The satellite detail view shows satellite passes and the sky chart during the first visible pass (if available).
public struct PassView: View {
    @State var viewModel: PassModel
    @State var isCompassEnabled: Bool = true

    var context: PassViewContext
    var elevationGraphFactory: ViewFactory<SatelliteElevationGraphContext, SatelliteElevationGraph>
    var skyChartFactory: ViewFactory<SkyChartContext<EmptyView, EmptyView>, SkyChart<EmptyView, EmptyView>>
    var passAlarmSettingsFactory: ViewFactory<PassAlarmSettingsModalViewContext, PassAlarmSettingsModalView>
    var detailedPassViewFactory: ViewFactory<DetailPassViewContext, DetailedPassView>

    @Environment(\.colorScheme) private var colorScheme

    public init(
        viewModel: PassModel,
        context: PassViewContext,
        elevationGraphFactory: ViewFactory<SatelliteElevationGraphContext, SatelliteElevationGraph>,
        skyChartFactory: ViewFactory<SkyChartContext<EmptyView, EmptyView>, SkyChart<EmptyView, EmptyView>>,
        passAlarmSettingsFactory: ViewFactory<PassAlarmSettingsModalViewContext, PassAlarmSettingsModalView>,
        detailedPassViewFactory: ViewFactory<DetailPassViewContext, DetailedPassView>,
        isCompassEnabled: Bool = true
    ) {
        self._isCompassEnabled = State(initialValue: isCompassEnabled)
        self.viewModel = viewModel
        self.context = context
        self.elevationGraphFactory = elevationGraphFactory
        self.skyChartFactory = skyChartFactory
        self.passAlarmSettingsFactory = passAlarmSettingsFactory
        self.detailedPassViewFactory = detailedPassViewFactory
    }
    
    @ViewBuilder private var compassButton: some View {
        Button {
            isCompassEnabled.toggle()
        } label: {
            Image(
                systemName: isCompassEnabled ? "safari.fill" : "safari"
            )
            .symbolRenderingMode(.monochrome)
            .resizable()
            .frame(width: 24, height: 24)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .if(!isCompassEnabled) { button in
            button.vibrancyEffect()
            .background(
                Color.clear.blurEffect()
            )
            .cornerRadius(8)
            .blurEffectStyle(colorScheme == .light ? .systemMaterialLight : .systemMaterialDark)
            .vibrancyEffectStyle(.fill)
            .padding(8)
        }
        .if(isCompassEnabled) { button in
            button.vibrancyEffect()
            .background(
                Color.clear.blurEffect()
            )
            .cornerRadius(8)
            .blurEffectStyle(colorScheme == .light ? .systemMaterialDark : .systemMaterialLight)
            .vibrancyEffectStyle(.fill)
            .padding(8)
        }
    }

    @ViewBuilder private func skyChart(in rect: CGRect) -> some View {
        MotionManagerView { deviceMotionResult in
            ZStack(alignment: .bottom) {
                ZStack(alignment: .top) {
                    skyChartFactory.view(
                        SkyChartContext(
                            satelliteInfo: context.satelliteInfo,
                            observer: context.observer,
                            passSnapshots: context.passSnapshots,
                            configs: .preset,
                            quality: .full,
                            starManager: context.starManager,
                            julianDateProvider: context.julianDateProvider,
                        )
                    )
                    .frame(height: min(rect.width, rect.height))
                    .rotationEffect(
                        isCompassEnabled ? .degrees(deviceMotionResult.content?.heading ?? 0) : .zero
                    )
                
                    HStack {
                        compassButton
                        
                        Spacer()
                        
                        Button {
                            viewModel.send(.showDetailPassView(true))
                        } label: {
                            Image(
                                systemName: "arrow.up.left.and.arrow.down.right"
                            )
                            .symbolRenderingMode(.monochrome)
                            .resizable()
                            .frame(width: 24, height: 24)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                        }
                        .vibrancyEffect()
                        .background(
                            Color.clear.blurEffect()
                        )
                        .cornerRadius(8)
                        .blurEffectStyle(colorScheme == .light ? .systemMaterialLight : .systemMaterialDark)
                        .vibrancyEffectStyle(.fill)
                        .padding(8)
                    }
                }
                
                if isCompassEnabled {
                    DeviceOrientationGuidanceView(
                        deviceMotionResult: deviceMotionResult,
                    )
                }
            }
        }
    }

    public var body: some View {
        GeometryReader { geometry in
            let rect = geometry.frame(in: .local)
            VStack(spacing: 20) {
                elevationGraphFactory.view(
                    SatelliteElevationGraphContext(
                        satelliteInfo: context.satelliteInfo,
                        selectedPassIndex: context.passIndex,
                        julianDateRange: context.julianDateRange,
                        observer: context.observer,
                        configs: .init(),
                        julianDateProvider: context.julianDateProvider,
                        selectedPass: context.passSnapshots.pass
                    )
                )
                .environment(\.julianDateRangeKey, context.julianDateRange)
                .frame(minHeight: 150, idealHeight: 240, maxHeight: 275, alignment: .leading)

                skyChart(in: rect)

                Spacer(minLength: 10)
            }
            .clipShape(Rectangle())
            .modifier(AppSurface())
        .navigationTitle(Date(julianDate: context.passSnapshots.pass.rise.julianDate).formatted(date: .abbreviated, time: .shortened))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(
                    placement: .principal
                ) {
                    VStack(alignment: .center, spacing: 4) {
                        Text(Date(julianDate: context.passSnapshots.pass.rise.julianDate).formatted(date: .abbreviated, time: .shortened))
                            .font(.headline)
                            .frame(alignment: .center)
                            .multilineTextAlignment(.center)
                        Text(PassView.descriptionToolbarText(for: context.passSnapshots.pass))
                            .lineLimit(2)
                            .font(.caption)
                            .frame(alignment: .center)
                            .multilineTextAlignment(.center)
                        Color.clear
                    }
                }

                ToolbarItem(
                    placement: .primaryAction
                ) {
                    Button {
                        if viewModel.state.scheduledPassNotifications.contains(where: { $0.id == context.passSnapshots.pass.notificationIdentifier }) {
                            viewModel.send(.unscheduleAlarm(context.passSnapshots.pass))
                        } else {
                            viewModel.send(.showAlarmConfiguration(true))
                        }
                    } label: {
                        if viewModel.state.scheduledPassNotifications.contains(where: { $0.id == context.passSnapshots.pass.notificationIdentifier }) {
                            Image(systemName: "bell.fill")
                        } else {
                            Image(systemName: "bell")
                        }
                    }
                }
            }
        }
        .fullScreenCover(
            isPresented: $viewModel.state.showAlarmConfigurationModal,
            onDismiss: {
                viewModel.send(.showAlarmConfiguration(false))
            },
            content: {
                passAlarmSettingsFactory.view(
                    PassAlarmSettingsModalViewContext(
                        satelliteName: context.satelliteCommonName,
                        category: context.category,
                        passSnapshots: context.passSnapshots,
                        observer: context.observer
                    )
                )
            }
        )
        .fullScreenCover(
            isPresented: Binding<Bool>(
                get: {
                    viewModel.state.showsDetailPassView
                },
                set: { newValue in
                    viewModel.send(.showDetailPassView(newValue))
                }
            ),
            content: {
                detailedPassViewFactory.view(
                    DetailPassViewContext(
                        satelliteInfo: context.satelliteInfo,
                        category: context.category,
                        julianDateRange: context.julianDateRange,
                        observer: context.observer,
                        passSnapshots: context.passSnapshots,
                        starManager: context.starManager,
                        julianDateProvider: context.julianDateProvider
                    )
                )
            }
        )
    }
}

public struct PassViewContext {
    public let passIndex: Int
    public let satelliteInfo: SatelliteInfo
    public let satelliteCommonName: String
    public let category: SatelliteCategory
    public let julianDateRange: ClosedRange<Double>
    public let observer: LatLonAlt
    public let passSnapshots: PassSnapshots
    public let starManager: AppStarCatalog
    public let julianDateProvider: () -> Double

    public init(
        passIndex: Int,
        satelliteInfo: SatelliteInfo,
        satelliteCommonName: String,
        category: SatelliteCategory,
        julianDateRange: ClosedRange<Double>,
        observer: LatLonAlt,
        passSnapshots: PassSnapshots,
        starManager: AppStarCatalog,
        julianDateProvider: @escaping () -> Double
    ) {
        self.passIndex = passIndex
        self.satelliteInfo = satelliteInfo
        self.satelliteCommonName = satelliteCommonName
        self.category = category
        self.julianDateRange = julianDateRange
        self.observer = observer
        self.passSnapshots = passSnapshots
        self.starManager = starManager
        self.julianDateProvider = julianDateProvider
    }
}

extension PassView {
    static func descriptionToolbarText(for pass: Pass) -> String {
        let riseDirection = Directions.angles[Int(floor(limit360(pass.rise.azim) / 45))]
        let setDirection = Directions.angles[Int(floor(limit360(pass.set.azim) / 45))]
        let format = NSLocalizedString(
            "PassView.descriptionToolbar.text",
            tableName: nil,
            bundle: .module,
            value: "Rises from %1$@ and sets into %2$@",
            comment: "The toolbar of the pass view describing the direction of the pass. The first and second arguments correspond to the directions of rising and setting."
        )
        return String(format: format, riseDirection, setDirection)
    }
}

#if DEBUG
struct PassView_Previews: PreviewProvider {
    static var previews: some View {
        let elements = try! Elements(
            raw: """
            TIANHE
            1 48274U 21035A   21152.91865056  .00003057  00000-0  33542-4 0  9993
            2 48274  41.4713  16.3199 0005053  25.9394 109.3813 15.65195495  5304
            """
        )
        let julianDateRange = Date().advanced(by: -60 * 60 * 2).julianDate...Date().advanced(by: 60 * 60 * 22).julianDate
        let satelliteInfo = try! SatelliteInfo(elements: elements)
        // 2000 Broadway, Redwood City, CA 94063
        let observer = LatLonAlt(37.486743000691185, -122.22655970246515, 0)
        let snapshots = try! satelliteInfo.generateSnapshots(
            observer: observer,
            julianDateRange: julianDateRange
        )
        let passSnapshots = try! satelliteInfo.findPasses(
            observer: observer,
            coarseSnapshots: snapshots
        )
        let skyChartContext = SkyChartContext(
            satelliteInfo: satelliteInfo,
            observer: observer,
            passSnapshots: passSnapshots.first!,
            configs: .preview,
            quality: .preview,
            starManager: StarManagerMock(),
            julianDateProvider: { Date().julianDate }
        )
        let elementPropagatorResources = ElementsPropagatorResources(
            satelliteTrails: [
                elements.noradIndex: SatelliteTrails(
                    observer: observer,
                    snapshots: snapshots,
                    passSnapshots: passSnapshots
                )
            ]
        )
        let satelliteGraphState = SatelliteElevationGraphState(
            satelliteElevationGraphResources: SatelliteElevationGraphResources(),
            elementsPropagatorResources: elementPropagatorResources
        )
        let skyChartState = SkyChartViewState(
            julianDateOffset: 0,
            resources: SkyChartResources(
                rasterizedSatellitePaths: [:],
                previewSatellitePaths: [:]
            ),
            backgroundSky: BackgroundSkyResources(),
            elementsPropagatorResources: elementPropagatorResources
        )
        let context = PassViewContext(
            passIndex: 0,
            satelliteInfo: try! SatelliteInfo(elements: elements),
            satelliteCommonName: "foo",
            category: .tianhe,
            julianDateRange: julianDateRange,
            observer: observer,
            passSnapshots: passSnapshots[0],
            starManager: StarManagerMock(),
            julianDateProvider: { Date().julianDate }
        )
        let elevationGraphContext = SatelliteElevationGraphContext(
            satelliteInfo: try! SatelliteInfo(elements: elements),
            selectedPassIndex: 0,
            julianDateRange: julianDateRange,
            observer: observer,
            configs: .init(),
            julianDateProvider: { Date().julianDate }
        )
        PassView(
            viewModel: .init(
                state: PassViewState()
            ),
            context: context,
            elevationGraphFactory: .pure(
                SatelliteElevationGraph(
                    viewModel: .init(
                        state: satelliteGraphState
                    ),
                    context: elevationGraphContext
                )
            ),
            skyChartFactory: .pure(
                SkyChart<EmptyView, EmptyView>(
                    viewModel: .init(
                        state: skyChartState
                    ),
                    context: skyChartContext,
                    backgroundSkyViewFactory: .pure(
                        BackgroundSkyView(
                            viewModel: .init(
                                state: BackgroundSkyViewState()
                            ),
                            context: BackgroundSkyViewContext(
                                observer: observer,
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
            ),
            passAlarmSettingsFactory: .crash,
            detailedPassViewFactory: .crash
        )
        .environment(\.julianDateRangeKey, julianDateRange)
        .environment(\.backgroundSkyJulianDateKey, passSnapshots[0].pass.rise.julianDate.roundJulianDate(.toMins(1)))
    }
}
#endif
