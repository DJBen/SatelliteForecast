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
    @State var isCompassEnabled: Bool = true

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.timeZone) private var timeZone
    @Environment(\.locale) private var locale

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
        isCompassEnabled: Bool = true
    ) {
        self._isCompassEnabled = State(initialValue: isCompassEnabled)
        self.viewModel = viewModel
        self.context = context
        self.skyChartFactory = skyChartFactory
        self.passAlarmSettingsFactory = passAlarmSettingsFactory
        self.detailedPassViewFactory = detailedPassViewFactory
    }
    
    private var compassButton: some View {
        Button {
            isCompassEnabled.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isCompassEnabled ? "safari.fill" : "safari")
                    .font(.body)
                Text("Compass", bundle: .module)
                    .font(.subheadline.weight(.medium))
                if isCompassEnabled {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .foregroundStyle(isCompassEnabled
                ? (colorScheme == .dark ? AppTheme.background : Color.white)
                : AppTheme.accent)
        }
        .accessibilityValue(isCompassEnabled ? "On" : "Off")
        .accessibilityAddTraits(isCompassEnabled ? .isSelected : [])
    }

    private var chartControls: some View {
        GlassEffectContainer(spacing: 16) {
            HStack(spacing: 16) {
                if isCompassEnabled {
                    compassButton.buttonStyle(.glassProminent)
                } else {
                    compassButton.buttonStyle(.glass)
                }

                Button {
                    viewModel.send(.showDetailPassView(true))
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.body)
                        Text("Full screen", bundle: .module)
                            .font(.subheadline.weight(.medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.roundedRectangle(radius: 16))
        }
    }

    private func skyChart(in rect: CGRect) -> some View {
        MotionManagerView { deviceMotionResult in
            VStack(spacing: 18) {
                skyChartFactory.view(
                    SkyChartContext(
                        satelliteInfo: context.satelliteInfo,
                        observer: context.observer,
                        passSnapshots: context.passSnapshots,
                        configs: .init(showPassInfoLabels: false),
                        quality: .full,
                        starManager: context.starManager,
                        julianDateProvider: context.julianDateProvider
                    )
                )
                .frame(width: max(0, min(rect.width, rect.height) - 32),
                       height: max(0, min(rect.width, rect.height) - 32))
                .rotationEffect(
                    isCompassEnabled ? .degrees(deviceMotionResult.content?.heading ?? 0) : .zero
                )
                .overlay {
                    if isCompassEnabled {
                        DeviceOrientationGuidanceView(deviceMotionResult: deviceMotionResult)
                            .padding(.horizontal, 20)
                    }
                }

                VStack(spacing: 20) {
                    chartControls
                    eventTable
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private var eventTable: some View {
        VStack(spacing: 0) {
            ForEach(Array(PassTimelineEvent.events(for: context.passSnapshots.pass).enumerated()), id: \.offset) { index, event in
                if index > 0 { Divider().padding(.leading, 48) }
                HStack(spacing: 12) {
                    ZStack {
                        Circle().strokeBorder(.secondary.opacity(0.3), lineWidth: 1)
                        Text("N").font(.system(size: 7, weight: .semibold)).offset(y: -13)
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
                            .font(.caption).foregroundStyle(.secondary)
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
