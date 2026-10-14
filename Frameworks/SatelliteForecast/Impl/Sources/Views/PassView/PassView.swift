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
    @AppStorage("passCompassEnabled") private var savedCompassEnabled = false
    @State private var compassOverride: Bool?
    @State private var showsPlanetarium = false

    private var isCompassEnabled: Bool {
        get { compassOverride ?? savedCompassEnabled }
        nonmutating set {
            if compassOverride != nil {
                compassOverride = newValue
            } else {
                savedCompassEnabled = newValue
            }
        }
    }

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.timeZone) private var timeZone
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var textSize

    var context: PassViewContext
    var skyChartFactory: ViewFactory<SkyChartContext<EmptyView, EmptyView>, SkyChart<EmptyView, EmptyView>>
    var passAlarmSettingsFactory: ViewFactory<PassAlarmSettingsModalViewContext, PassAlarmSettingsModalView>
    var detailedPassViewFactory: ViewFactory<DetailPassViewContext, DetailedPassView>

    public init(
        viewModel: PassModel,
        context: PassViewContext,
        skyChartFactory: ViewFactory<SkyChartContext<EmptyView, EmptyView>, SkyChart<EmptyView, EmptyView>>,
        passAlarmSettingsFactory: ViewFactory<PassAlarmSettingsModalViewContext, PassAlarmSettingsModalView>,
        detailedPassViewFactory: ViewFactory<DetailPassViewContext, DetailedPassView>,
        isCompassEnabled: Bool? = nil
    ) {
        // Explicit overrides keep snapshot fixtures independent of the saved preference.
        self._compassOverride = State(initialValue: isCompassEnabled)
        self.viewModel = viewModel
        self.context = context
        self.skyChartFactory = skyChartFactory
        self.passAlarmSettingsFactory = passAlarmSettingsFactory
        self.detailedPassViewFactory = detailedPassViewFactory
    }
    
    private func chartControls(vertical: Bool = false) -> some View {
        PassChartControls(
            isCompassEnabled: Binding(get: { isCompassEnabled }, set: { isCompassEnabled = $0 }),
            openChart: { viewModel.send(.showDetailPassView(true)) },
            openPlanetarium: { showsPlanetarium = true }, vertical: vertical
        )
    }

    private func skyChart(in rect: CGRect) -> some View {
        let wide = rect.width >= 880 && !textSize.isAccessibilitySize
        let side = wide
            ? max(240, min(700, min(rect.width - 388, rect.height - 80)))
            : max(220, min(620, min(rect.width - 64, rect.height - 340)))
        let layout = wide ? AnyLayout(HStackLayout(alignment: .center, spacing: 32)) : AnyLayout(VStackLayout(spacing: 20))
        return MotionManagerView { deviceMotionResult in
            layout {
                chart(deviceMotionResult: deviceMotionResult, diameter: side)
                    .frame(width: side, height: side)
                    .padding(24)
                VStack(alignment: .leading, spacing: 20) {
                    if wide {
                        Text(context.satelliteCommonName).font(.title2.weight(.semibold))
                        Text(Self.descriptionToolbarText(for: context.passSnapshots.pass))
                            .font(.subheadline).foregroundStyle(AppTheme.muted)
                    }
                    chartControls(vertical: wide)
                    eventTable.padding(.horizontal, 16)
                        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 20))
                        .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(AppTheme.border, lineWidth: 1) }
                }
                .frame(width: wide ? 300 : nil)
                .frame(maxWidth: wide ? 300 : 620)
                .padding(.horizontal, wide ? 0 : 20)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func chart(deviceMotionResult: Loadable<CMDeviceMotion, Error>, diameter: CGFloat) -> some View {
        skyChartFactory.view(
            SkyChartContext(
                satelliteInfo: context.satelliteInfo,
                observer: context.observer,
                passSnapshots: context.passSnapshots,
                configs: .init(backgroundSkyConfigs: SkyChartDetail.configs(diameter: diameter), showPassInfoLabels: false),
                quality: .full,
                starManager: context.starManager,
                julianDateProvider: context.julianDateProvider
            )
        )
        .rotationEffect(
            isCompassEnabled ? .degrees(deviceMotionResult.content?.heading ?? 0) : .zero
        )
        // Azimuth labels sit outside the circle, including after compass rotation.
        .overlay {
            if isCompassEnabled {
                DeviceOrientationGuidanceView(deviceMotionResult: deviceMotionResult)
                    .padding(.horizontal, 4)
            }
        }

    }

    private var isAlarmScheduled: Bool {
        viewModel.state.scheduledPassNotifications.contains {
            $0.id == context.passSnapshots.pass.notificationIdentifier
        }
    }

    private var manualAlarmControl: some View {
        Button {
            viewModel.send(.showAlarmConfiguration(true))
        } label: {
            Image(systemName: isAlarmScheduled ? "alarm.fill" : "alarm")
        }
        .accessibilityLabel(Text(isAlarmScheduled ? "View local alarm" : "Set local alarm", bundle: .module))
        .accessibilityAddTraits(isAlarmScheduled ? [.isSelected] : [])
        .accessibilityIdentifier("pass.manualAlarm")
    }

    private var eventTable: some View {
        VStack(spacing: 0) {
            ForEach(Array(PassTimelineEvent.events(for: context.passSnapshots.pass).enumerated()), id: \.offset) { index, event in
                if index > 0 { Divider().padding(.leading, 48) }
                HStack(spacing: 12) {
                    ZStack {
                        Circle().strokeBorder(.secondary.opacity(0.3), lineWidth: 1)
                        Text("Compass.northAbbreviation", bundle: .module).font(.system(size: 7, weight: .semibold)).offset(y: -13)
                        Image(systemName: "location.north.fill")
                            .font(.system(size: 16))
                            .rotationEffect(.degrees(event.position.azim))
                    }
                    .frame(width: 36, height: 36)
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(LocalizedStringKey(event.title), bundle: .module).font(.subheadline.weight(.medium))
                        Text("\(Int(event.position.azim.rounded()) % 360)° azimuth · \(Int(event.position.elev.rounded()))° elevation", bundle: .module)
                            .font(.caption).foregroundStyle(AppTheme.muted)
                    }
                    Spacer(minLength: 8)
                    Text(Date(julianDate: event.position.julianDate), format: .dateTime.hour().minute().second())
                        .font(.subheadline.monospacedDigit())
                }
                .padding(.vertical, 10)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var passDateTitle: String {
        Date(julianDate: context.passSnapshots.pass.rise.julianDate).formatted(
            Date.FormatStyle(date: .abbreviated, time: .shortened, locale: locale, timeZone: timeZone))
    }

    public var body: some View {
        GeometryReader { geometry in
            let rect = geometry.frame(in: .local)
            ScrollView {
                skyChart(in: rect)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
            }
            .modifier(AppSurface())
            .navigationTitle(passDateTitle)
        .analyticsScreen(.passDetail)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(
                    placement: .principal
                ) {
                    VStack(alignment: .center, spacing: 4) {
                        Text(passDateTitle)
                            .font(.headline)
                            .frame(alignment: .center)
                            .multilineTextAlignment(.center)
                        Text(PassView.descriptionToolbarText(for: context.passSnapshots.pass))
                            .lineLimit(2)
                            .font(.caption)
                            .frame(alignment: .center)
                            .multilineTextAlignment(.center)
                    }
                }

                ToolbarItem(
                    placement: .primaryAction
                ) {
                    manualAlarmControl
                }
            }
        }
        .modifier(FirstCompassUseTutorial(isCompassEnabled: isCompassEnabled))
        .fullScreenCover(isPresented: $showsPlanetarium) {
            PlanetariumView(context: context, debug: viewModel.session?.debug)
        }
        .sheet(
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
                ).presentationSizing(.form)
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


/// A compact summary of the visible portion, with horizon events for nonvisible passes.
struct PassTimelineEvent {
    let title: String
    let position: Pass.DatePosition

    static func events(for pass: Pass) -> [Self] {
        var start = pass.rise
        var end = pass.set
        if pass.visibility == .visible {
            if !pass.illumination.initiallyIlluminated,
               let change = pass.illumination.changes.first(where: {
                   if case .exitsShadow = $0 { return true }; return false
               }) {
                start = change.datePosition
            }
            if let change = pass.illumination.changes.last,
               case .entersShadow(let position) = change {
                end = position
            }
        }
        var events = [Self(title: start == pass.rise ? "Rises" : "Becomes visible", position: start)]
        if pass.culmination.julianDate > start.julianDate && pass.culmination.julianDate < end.julianDate {
            events.append(Self(title: "Culminates", position: pass.culmination))
        }
        events.append(Self(title: end == pass.set ? "Sets" : "Disappears", position: end))
        return events
    }
}
