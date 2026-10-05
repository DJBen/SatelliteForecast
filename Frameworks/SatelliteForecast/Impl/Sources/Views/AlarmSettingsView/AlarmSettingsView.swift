import SwiftUI
import CoreLocation
import UserNotifications
@preconcurrency import SatelliteKit
import SatelliteForecast

public struct AlarmSettingsView: View {
    let notifications: [ScheduledPassNotification]
    let choosePass: (() -> Void)?
    let deleteNotifications: (Set<String>) -> Void
    let alarmEditor: ((ScheduledPassNotification) -> PassAlarmSettingsModalView)?
    let authorizationStatus: UNAuthorizationStatus?
    let isRequestingAuthorization: Bool
    let enableNotifications: (() -> Void)?
    let openNotificationSettings: (() -> Void)?
    @State private var editMode: EditMode = .inactive
    @State private var selectedAlarm: ScheduledPassNotification?
    @Environment(\.locale) private var locale
    @Environment(\.timeZone) private var timeZone
    @Environment(\.dynamicTypeSize) private var textSize

    public init(
        notifications: [ScheduledPassNotification],
        deleteNotifications: @escaping (Set<String>) -> Void,
        choosePass: (() -> Void)? = nil,
        alarmEditor: ((ScheduledPassNotification) -> PassAlarmSettingsModalView)? = nil,
        authorizationStatus: UNAuthorizationStatus? = nil,
        isRequestingAuthorization: Bool = false,
        enableNotifications: (() -> Void)? = nil,
        openNotificationSettings: (() -> Void)? = nil
    ) {
        self.notifications = notifications.sorted {
            if $0.notification.alertJulianDate == $1.notification.alertJulianDate { return $0.id < $1.id }
            return $0.notification.alertJulianDate < $1.notification.alertJulianDate
        }
        self.deleteNotifications = deleteNotifications
        self.choosePass = choosePass
        self.alarmEditor = alarmEditor
        self.authorizationStatus = authorizationStatus
        self.isRequestingAuthorization = isRequestingAuthorization
        self.enableNotifications = enableNotifications
        self.openNotificationSettings = openNotificationSettings
    }

    static func showsPermissionCard(_ status: UNAuthorizationStatus?) -> Bool {
        status == .notDetermined || status == .denied
    }

    private var permissionCard: some View {
        let denied = authorizationStatus == .denied
        return VStack(alignment: .leading, spacing: 16) {
            Label {
                Text(denied ? "Turn notifications back on" : "Never miss a station pass", bundle: .module)
            } icon: {
                Image(systemName: denied ? "bell.slash" : "bell.badge").foregroundStyle(AppTheme.accent)
            }
            .font(.title3.weight(.semibold))
            Text(denied
                 ? "Notifications are off. Allow notifications in iOS Settings to receive automatic ISS and Tiangong alerts and your local alarms."
                 : "Get automatic alerts for visible ISS and Tiangong passes. Allow notifications to receive these alerts and local alarms with sound.", bundle: .module)
                .font(.subheadline).foregroundStyle(AppTheme.muted)
            if denied, let openNotificationSettings {
                Button(action: openNotificationSettings) {
                    Label { Text("Open notification settings", bundle: .module) } icon: { Image(systemName: "arrow.up.right") }
                        .frame(maxWidth: .infinity, minHeight: 32)
                }
                .accessibilityIdentifier("alarms.notificationSettings")
                .buttonStyle(.borderedProminent)
                .foregroundStyle(Color(uiColor: .systemBackground))
            } else if let enableNotifications {
                Button(action: enableNotifications) {
                    HStack {
                        if isRequestingAuthorization { ProgressView() }
                        Text("Enable notifications", bundle: .module)
                    }.frame(maxWidth: .infinity, minHeight: 32)
                }
                .accessibilityIdentifier("alarms.enableNotifications")
                .disabled(isRequestingAuthorization)
                .buttonStyle(.borderedProminent)
                .foregroundStyle(Color(uiColor: .systemBackground))
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 8)
        .listRowBackground(AppTheme.surface)
        .accessibilityIdentifier("alarms.permissionCard")
    }

    private func alarmDate(_ item: ScheduledPassNotification) -> Date {
        Date(julianDate: item.notification.alertJulianDate)
    }

    private func dateColumn(_ date: Date) -> some View {
        VStack(spacing: 3) {
            Text(date, format: Date.FormatStyle(locale: locale, timeZone: timeZone).month(.abbreviated).day())
                .font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.accent)
            Text(date, format: Date.FormatStyle(locale: locale, timeZone: timeZone).weekday(.abbreviated))
                .font(.caption).foregroundStyle(AppTheme.muted)
        }
        .frame(width: 66)
        .padding(.vertical, 12)
        .background(AppTheme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private func alarmContent(_ item: ScheduledPassNotification) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(alarmDate(item), format: Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, timeZone: timeZone))
                .font(.title2.weight(.semibold).monospacedDigit()).foregroundStyle(AppTheme.text)
                .fixedSize(horizontal: false, vertical: true)
            Text(item.notification.satelliteName).font(.subheadline.weight(.medium)).foregroundStyle(AppTheme.accent)
            Text(Self.alarmOffsetDescription(timing: item.notification.timing, offset: item.notification.timeOffset, locale: locale))
                .font(.caption).foregroundStyle(AppTheme.muted)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func itemView(_ item: ScheduledPassNotification) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if textSize.isAccessibilitySize {
                Text(alarmDate(item), format: Date.FormatStyle(date: .abbreviated, time: .omitted, locale: locale, timeZone: timeZone))
                    .font(.subheadline).foregroundStyle(AppTheme.accent)
                alarmContent(item)
            } else {
                HStack(spacing: 14) {
                    dateColumn(alarmDate(item))
                    alarmContent(item)
                    Spacer(minLength: 0)
                    if alarmEditor != nil { Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(AppTheme.muted) }
                }
            }
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text(Self.passDescription(pass: item.notification.pass, locale: locale, timeZone: timeZone)))
    }

    private var emptyAlarms: some View {
        VStack(spacing: 14) {
            Image(systemName: "alarm").font(.largeTitle).foregroundStyle(AppTheme.accent)
            Text("No local alarms yet", bundle: .module).font(.headline)
            Text("Choose an upcoming pass to set a one-off reminder.", bundle: .module)
                .font(.subheadline).foregroundStyle(AppTheme.muted).multilineTextAlignment(.center)
            if let choosePass {
                Button(action: choosePass) { Text("Choose a pass", bundle: .module).frame(minHeight: 28) }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.capsule)
                    .foregroundStyle(AppTheme.text)
                    .accessibilityIdentifier("alarms.choosePass")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .listRowBackground(AppTheme.surface)
    }

    private var headerActions: some View {
        HStack(spacing: 10) {
            if !notifications.isEmpty {
                EditButton()
                if let choosePass {
                    Button(action: choosePass) {
                        Label { Text("Choose a pass", bundle: .module) } icon: { Image(systemName: "plus") }
                            .labelStyle(.iconOnly)
                    }
                    .accessibilityIdentifier("alarms.add")
                }
            }
        }
        .font(.subheadline)
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .fixedSize()
    }

    private var pageHeader: some View {
        Group {
            if textSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Alarms", bundle: .module).font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
                    headerActions
                }.frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(alignment: .center) {
                    Text("Alarms", bundle: .module).font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 8)
                    headerActions
                }
            }
        }
        .foregroundStyle(AppTheme.text)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(AppTheme.pageBackground)
    }

    public var body: some View {
        List {
            if Self.showsPermissionCard(authorizationStatus) {
                Section { permissionCard }
            }
            Section {
                if notifications.isEmpty { emptyAlarms }
                else {
                    ForEach(notifications) { item in
                        Group {
                            if alarmEditor != nil {
                                Button { selectedAlarm = item } label: { itemView(item) }
                                    .buttonStyle(.plain)
                                    .accessibilityHint(Text("Edit alarm", bundle: .module))
                                    .accessibilityIdentifier("alarms.edit")
                            } else { itemView(item) }
                        }
                        .listRowBackground(AppTheme.surface)
                    }
                    .onDelete(perform: deleteAlarms)
                }
            } header: {
                Text("Local alarms", bundle: .module).font(.subheadline.weight(.semibold)).textCase(nil)
            }
        }
        .listStyle(.insetGrouped)
        .contentMargins(.top, 8, for: .scrollContent)
        .scrollContentBackground(.hidden)
        .modifier(AppSurface())
        .navigationTitle(Text("Alarms", bundle: .module))
        .analyticsScreen(.alarms)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) { pageHeader }
        .environment(\.editMode, $editMode)
        .sheet(item: $selectedAlarm) { alarm in
            if let alarmEditor { alarmEditor(alarm) }
        }

    }

    func deleteAlarms(at offsets: IndexSet) {
        let ids = Set(offsets.filter { notifications.indices.contains($0) }.map { notifications[$0].id })
        if !ids.isEmpty { deleteNotifications(ids) }
    }
}

extension AlarmSettingsView {
    static func alarmOffsetDescription(timing: PassNotification.Timing, offset: TimeInterval, locale: Locale = .current) -> String {
        let localizedBundle = AppLocalization.localizedBundle(locale)
        let beforeFormat: String
        switch timing {
        case .reachesTenDegrees:
            beforeFormat = AppLocalization.text("%@ before reaching 10°", locale: locale)
        case .rise:
            beforeFormat = NSLocalizedString(
                "AlarmSettingsView.alarmOffsetDescription.rise",
                tableName: nil,
                bundle: localizedBundle,
                value: "%@ before rise",
                comment: "The timing and offset description for the alarm in the alarm settings view, rise."
            )

        case .transit:
            beforeFormat = NSLocalizedString(
                "AlarmSettingsView.alarmOffsetDescription.culmination",
                tableName: nil,
                bundle: localizedBundle,
                value: "%@ before highest point",
                comment: "The timing and offset description for the alarm in the alarm settings view, culmination."
            )

        case .set:
            beforeFormat = NSLocalizedString(
                "AlarmSettingsView.alarmOffsetDescription.set",
                tableName: nil,
                bundle: localizedBundle,
                value: "%@ before set",
                comment: "The timing and offset description for the alarm in the alarm settings view, set."
            )

        case .highestIlluminated:
            beforeFormat = NSLocalizedString(
                "AlarmSettingsView.alarmOffsetDescription.highestIlluminated",
                tableName: nil,
                bundle: localizedBundle,
                value: "%@ before highest illuminated",
                comment: "The timing and offset description for the alarm in the alarm settings view, highest illuminated."
            )
        }

        let moment: String
        switch timing {
        case .reachesTenDegrees: moment = AppLocalization.text("Reaches 10°", locale: locale)
        case .rise: moment = AppLocalization.text("Pass starts", locale: locale)
        case .transit: moment = AppLocalization.text("PassAlarmSettingsModalView.timingCell.transit", locale: locale)
        case .set: moment = AppLocalization.text("Pass ends", locale: locale)
        case .highestIlluminated: moment = AppLocalization.text("PassAlarmSettingsModalView.timingCell.highestIlluminated", locale: locale)
        }
        if offset == 0 { return moment }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = abs(offset) < 60 ? [.second] : [.hour, .minute]
        formatter.unitsStyle = .short
        var calendar = Calendar.current
        calendar.locale = locale
        formatter.calendar = calendar
        let duration = formatter.string(from: abs(offset)) ?? ""
        if offset > 0 { return String(format: AppLocalization.text("%@ after %@", locale: locale), duration, moment) }
        return String(format: beforeFormat, duration)
    }

    static func passDescription(pass: Pass, locale: Locale = .current, timeZone: TimeZone = .current) -> String {
        let localizedBundle = AppLocalization.localizedBundle(locale)
        let format = NSLocalizedString(
            "AlarmSettingsView.passDescription",
            tableName: nil,
            bundle: localizedBundle,
            value: "Rises at %@ and sets at %@.",
            comment: "The pass description for each alarm in the alarm settings view"
        )

        return String(
            format: format,
            Date(julianDate: pass.rise.julianDate).formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, timeZone: timeZone)),
            Date(julianDate: pass.set.julianDate).formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, timeZone: timeZone))
        )
    }

    static func passVisibilityDescription(pass: Pass) -> String {
        let visibleFormat = NSLocalizedString(
            "AlarmSettingsView.passVisibilityDescription.visible",
            tableName: nil,
            bundle: .module,
            value: "Max visible elevation %.1f degrees.",
            comment: "The pass description for each alarm in the alarm settings view"
        )

        let daytimeFormat = NSLocalizedString(
            "AlarmSettingsView.passVisibilityDescription.daytime",
            tableName: nil,
            bundle: .module,
            value: "The pass occurs during daylight with a max elevation of %.1f degrees.",
            comment: "The pass description for each alarm in the alarm settings view"
        )

        let unlitFormat = NSLocalizedString(
            "AlarmSettingsView.passVisibilityDescription.unlit",
            tableName: nil,
            bundle: .module,
            value: "The pass is not illuminated with a max elevation of %.1f degrees.",
            comment: "The pass description for each alarm in the alarm settings view"
        )

        switch pass.visibility {
        case .visible:
            return String(
                format: visibleFormat,
                pass.highestIlluminated?.elev ?? 0
            )
        case .daylight:
            return String(
                format: daytimeFormat,
                pass.culmination.elev
            )
        case .unlit:
            return String(
                format: unlitFormat,
                pass.culmination.elev
            )
        }
    }

}
