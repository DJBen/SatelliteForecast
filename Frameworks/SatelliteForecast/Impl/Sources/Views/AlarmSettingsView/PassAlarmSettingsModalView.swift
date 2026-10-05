//
//  PassAlarmSettingsModalView.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 4/21/22.
//

import SwiftUI
import SatelliteForecast
@preconcurrency import SatelliteKit

public struct PassAlarmSettingsModalViewState {
    public var scheduledPassNotifications: Set<ScheduledPassNotification>
    public var showAlarmConfigurationModal: Bool

    public init(
        scheduledPassNotifications: Set<ScheduledPassNotification> = [],
        showAlarmConfigurationModal: Bool = false
    ) {
        self.scheduledPassNotifications = scheduledPassNotifications
        self.showAlarmConfigurationModal = showAlarmConfigurationModal
    }
}

extension PassAlarmSettingsModalViewState: Equatable {}

public struct PassAlarmSettingsModalViewContext {
    public let satelliteName: String
    public let category: SatelliteCategory
    public let pass: Pass
    public let passSnapshots: PassSnapshots?
    public let observer: LatLonAlt

    public init(
        satelliteName: String,
        category: SatelliteCategory,
        passSnapshots: PassSnapshots,
        observer: LatLonAlt
    ) {
        self.satelliteName = satelliteName
        self.category = category
        self.pass = passSnapshots.pass
        self.passSnapshots = passSnapshots
        self.observer = observer
    }

    /// Saved alarms retain their pass and observer, without requiring a fresh orbit lookup.
    public init(notification: PassNotification) {
        satelliteName = notification.satelliteName
        category = notification.category
        pass = notification.pass
        passSnapshots = nil
        observer = notification.observer
    }

}

/// The draft preserves saved absolute times while editing a pass-relative moment
/// and an explicit date, including across midnight.
struct PassAlarmDraft {
    let pass: Pass
    var timing: PassNotification.Timing
    private(set) var timeOffset: TimeInterval
    private let savedDate: Date?

    init(pass: Pass, notification: PassNotification? = nil) {
        self.pass = pass
        timing = notification?.timing ?? .rise
        if timing == .set || (timing == .highestIlluminated && pass.highestIlluminated == nil)
            || (timing == .reachesTenDegrees && pass.reachesTenDegrees == nil) { timing = .rise }
        timeOffset = 0
        savedDate = notification.map { Date(julianDate: $0.alertJulianDate) }
        if let savedDate {
            // Preserve the saved absolute time if a fresh TLE slightly moves the event.
            timeOffset = savedDate.timeIntervalSince(eventDate)
        }
    }

    var eventDate: Date {
        let position: Pass.DatePosition
        switch timing {
        case .rise: position = pass.rise
        case .transit: position = pass.culmination
        case .set: position = pass.set
        case .reachesTenDegrees: position = pass.reachesTenDegrees ?? pass.rise
        case .highestIlluminated: position = pass.highestIlluminated ?? pass.rise
        }
        return Date(julianDate: position.julianDate)
    }

    var date: Date {
        get { eventDate.addingTimeInterval(timeOffset) }
        set { timeOffset = newValue.timeIntervalSince(eventDate) }
    }

    var dateRange: ClosedRange<Date> {
        // Retain legacy alarms with longer lead times instead of silently moving them.
        let retainedDate = savedDate ?? eventDate
        return min(date, min(retainedDate, eventDate.addingTimeInterval(-86400)))...max(date, max(retainedDate, eventDate))
    }

    mutating func select(_ moment: PassNotification.Timing) { timing = moment }

    var availableMoments: [PassNotification.Timing] {
        [.rise, .reachesTenDegrees, .transit, .highestIlluminated].filter {
            ($0 != .highestIlluminated || pass.highestIlluminated != nil)
                && ($0 != .reachesTenDegrees || pass.reachesTenDegrees != nil)
        }.sorted {
            var lhs = self; lhs.select($0)
            var rhs = self; rhs.select($1)
            return lhs.eventDate < rhs.eventDate
        }
    }
}

/// A modal view for alarm settings of an individual pass.
public struct PassAlarmSettingsModalView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.timeZone) private var timeZone
    @State var viewModel: PassAlarmModel
    @State private var draft: PassAlarmDraft
    @State private var showsSaveError = false
    let context: PassAlarmSettingsModalViewContext
    private let initialDraft: PassAlarmDraft

    public init(viewModel: PassAlarmModel, context: PassAlarmSettingsModalViewContext) {
        self.viewModel = viewModel
        self.context = context
        let saved = viewModel.state.scheduledPassNotifications.first {
            $0.id == context.pass.notificationIdentifier
        }?.notification
        let draft = PassAlarmDraft(pass: context.pass, notification: saved)
        self.initialDraft = draft
        self._draft = State(initialValue: draft)
    }

    private var isNotificationScheduled: Bool {
        viewModel.state.scheduledPassNotifications.contains {
            $0.id == context.pass.notificationIdentifier
        }
    }

    private var hasChanges: Bool {
        draft.timing != initialDraft.timing || abs(draft.date.timeIntervalSince(initialDraft.date)) > 0.5
    }

    private var moments: [PassNotification.Timing] { draft.availableMoments }

    private func momentName(_ timing: PassNotification.Timing) -> Text {
        switch timing {
        case .rise: return Text("Pass starts", bundle: .module)
        case .transit: return Text("PassAlarmSettingsModalView.timingCell.transit", bundle: .module)
        case .highestIlluminated: return Text("PassAlarmSettingsModalView.timingCell.highestIlluminated", bundle: .module)
        case .set: return Text("Pass ends", bundle: .module)
        case .reachesTenDegrees: return Text("Reaches 10°", bundle: .module)
        }
    }

    private func formattedTime(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, timeZone: timeZone))
    }

    private var passHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(context.satelliteName).font(.title3.weight(.semibold))
            Text(Date(julianDate: context.pass.rise.julianDate),
                 format: Date.FormatStyle(date: .complete, time: .omitted, locale: locale, timeZone: timeZone))
                .font(.subheadline).foregroundStyle(AppTheme.muted)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var momentPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pass moment", bundle: .module).font(.subheadline).foregroundStyle(AppTheme.muted)
            Picker(selection: Binding(get: { draft.timing }, set: { draft.select($0) })) {
                ForEach(moments, id: \.self) { moment in
                    let date = { var value = draft; value.select(moment); return value.eventDate }()
                    (momentName(moment) + Text(verbatim: " · " + formattedTime(date))).tag(moment)
                }
            } label: { Text("Pass moment", bundle: .module) }
            .pickerStyle(.menu)
            .labelsHidden()
            .font(.headline)
            .accessibilityIdentifier("alarm.passMoment")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius))
    }

    private var timePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label { Text("Alarm time", bundle: .module) } icon: { Image(systemName: "alarm") }
                .font(.headline)
            Text(draft.date, format: Date.FormatStyle(date: .abbreviated, time: .shortened,
                                                     locale: locale, timeZone: timeZone))
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(AppTheme.accent)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("alarm.selectedTime")
            DatePicker(selection: $draft.date, in: draft.dateRange, displayedComponents: [.date, .hourAndMinute]) {
                Text("Alarm time", bundle: .module)
            }
            .datePickerStyle(.wheel)
            .labelsHidden()
            .accessibilityIdentifier("alarm.timePicker")
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius))
    }

    private func save() {
        let notification = PassNotification(pass: context.pass,
            satelliteName: context.satelliteName, category: context.category,
            observer: context.observer, timing: draft.timing, timeOffset: draft.timeOffset)
        Task {
            guard !viewModel.isSaving else { return }
            if await viewModel.save(notification, snapshots: context.passSnapshots) { dismiss() }
            else { showsSaveError = true }
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Button(action: save) {
                HStack {
                    if viewModel.isSaving { ProgressView() }
                    Text(isNotificationScheduled ? "Save changes" : "Set alarm", bundle: .module)
                }
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.borderedProminent)
            .foregroundStyle(viewModel.isSaving || (isNotificationScheduled && !hasChanges)
                             ? AppTheme.muted : Color(uiColor: .systemBackground))
            .disabled(viewModel.isSaving || (isNotificationScheduled && !hasChanges))
            .accessibilityIdentifier("alarm.save")
            if isNotificationScheduled {
                Button(role: .destructive) {
                    viewModel.send(.unscheduleAlarm(context.pass))
                    dismiss()
                } label: {
                    Text("PassAlarmSettingsModalView.deleteButton.title", bundle: .module)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .disabled(viewModel.isSaving)
                .accessibilityIdentifier("alarm.delete")
            }
        }
        .padding(16)
        .background(AppTheme.background)
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    passHeader
                    momentPicker
                    timePicker
                }
                .padding(20)
                .disabled(viewModel.isSaving)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { footer }
            .modifier(AppSurface())
            .navigationTitle(Text(isNotificationScheduled ? "Edit alarm" : "Set local alarm", bundle: .module))
            .analyticsScreen(.alarmSetup)
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(viewModel.isSaving)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("Cancel", bundle: .module) }
                        .disabled(viewModel.isSaving)
                }
            }
            .alert(Text("Couldn't set alarm", bundle: .module), isPresented: $showsSaveError) {
                Button(AppLocalization.text("OK"), role: .cancel) { }
            } message: { Text(viewModel.saveError ?? AppLocalization.text("Please try again.")) }
        }
    }
}

extension View {
    /// Applies the given transform if the given condition evaluates to `true`.
    /// - Parameters:
    ///   - condition: The condition to evaluate.
    ///   - transform: The transform to apply to the source `View`.
    /// - Returns: Either the original `View` or the modified `View` if the condition is `true`.
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
