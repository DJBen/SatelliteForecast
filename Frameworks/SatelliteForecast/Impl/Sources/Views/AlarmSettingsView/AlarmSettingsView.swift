//
//  AlarmSettingsView.swift
//  AlarmSettingsView
//
//  Created by Ben Lu on 8/20/21.
//

import SwiftUI
import CoreLocation
@preconcurrency import SatelliteKit
import SatelliteForecast

public struct AlarmSettingsView: View {
    let notifications: [ScheduledPassNotification]
    let deleteNotifications: (Set<String>) -> Void

    public init(
        notifications: [ScheduledPassNotification],
        deleteNotifications: @escaping (Set<String>) -> Void
    ) {
        self.notifications = notifications.sorted {
            if $0.notification.pass.rise.julianDate == $1.notification.pass.rise.julianDate { return $0.id < $1.id }
            return $0.notification.pass.rise.julianDate < $1.notification.pass.rise.julianDate
        }
        self.deleteNotifications = deleteNotifications
    }
    
    @ViewBuilder private func itemView(_ item: ScheduledPassNotification) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.notification.satelliteName)
                    .font(.headline)
                    .foregroundColor(Color(UIColor.label))
                
                Spacer()
                
                Text(Date(julianDate: item.notification.alertJulianDate).formatted())
                    .font(.subheadline)
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
                    .foregroundColor(AppTheme.muted)
            }

            if item.notification.timeOffset != 0 {
                Text(
                    AlarmSettingsView.alarmOffsetDescription(
                        timing: item.notification.timing,
                        offset: item.notification.timeOffset
                    )
                )
                .font(.caption)
                .foregroundColor(AppTheme.muted)
            }
                        
            VStack(alignment: .leading, spacing: 4) {
                Text(AlarmSettingsView.passDescription(pass: item.notification.pass))
                    .font(.caption)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.primary)
                
                Text(AlarmSettingsView.passVisibilityDescription(pass: item.notification.pass))
                    .font(.caption)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.primary)
            }
        }
        .padding([.top, .bottom], 4)
    }
    
    @ViewBuilder var alarmList: some View {
        List {
            if notifications.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "bell.circle")
                        .font(.title)
                        .foregroundColor(AppTheme.muted)
                    Text(
                    """
                    Your alarms will appear here. Schedule an alarm by tapping the \(Image(systemName: "bell")) inside a pass.
                    """,
                    bundle: .module
                    )
                    .foregroundColor(AppTheme.muted)
                    .multilineTextAlignment(.center)
                }
                .padding(
                    EdgeInsets(
                        top: 16,
                        leading: 32,
                        bottom: 16,
                        trailing: 32
                    )
                )
            } else {
                ForEach(notifications) { item in
                    itemView(item)
                }
                .onDelete(perform: deleteAlarms)
            }
        }
        .listStyle(.insetGrouped)
        .animation(
            .spring(),
            value: notifications
        )
    }
    
    func deleteAlarms(at offsets: IndexSet) {
        let ids = Set(offsets.filter { notifications.indices.contains($0) }.map { notifications[$0].id })
        guard !ids.isEmpty else { return }
        deleteNotifications(ids)
    }

    public var body: some View {
        alarmList.modifier(AppSurface())
        .navigationTitle(Text("Alarms", bundle: .module, comment: "Noun, as in alarm clock."))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            EditButton()
        }
    }
}

extension AlarmSettingsView {
    static func alarmOffsetDescription(timing: PassNotification.Timing, offset: TimeInterval) -> String {
        let beforeFormat: String
        switch timing {
        case .rise:
            beforeFormat = NSLocalizedString(
                "AlarmSettingsView.alarmOffsetDescription.rise",
                tableName: nil,
                bundle: .module,
                value: "%@ before rise",
                comment: "The timing and offset description for the alarm in the alarm settings view, rise."
            )

        case .transit:
            beforeFormat = NSLocalizedString(
                "AlarmSettingsView.alarmOffsetDescription.culmination",
                tableName: nil,
                bundle: .module,
                value: "%@ before highest point",
                comment: "The timing and offset description for the alarm in the alarm settings view, culmination."
            )

        case .set:
            beforeFormat = NSLocalizedString(
                "AlarmSettingsView.alarmOffsetDescription.set",
                tableName: nil,
                bundle: .module,
                value: "%@ before set",
                comment: "The timing and offset description for the alarm in the alarm settings view, set."
            )

        case .highestIlluminated:
            beforeFormat = NSLocalizedString(
                "AlarmSettingsView.alarmOffsetDescription.highestIlluminated",
                tableName: nil,
                bundle: .module,
                value: "%@ before highest illuminated",
                comment: "The timing and offset description for the alarm in the alarm settings view, highest illuminated."
            )
        }

        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .short

        return String(
            format: beforeFormat,
            formatter.string(from: abs(offset))!
        )
    }

    static func passDescription(pass: Pass) -> String {
        let format = NSLocalizedString(
            "AlarmSettingsView.passDescription",
            tableName: nil,
            bundle: .module,
            value: "Rises at %@ and sets at %@.",
            comment: "The pass description for each alarm in the alarm settings view"
        )

        return String(
            format: format,
            Date(julianDate: pass.rise.julianDate).formatted(date: .omitted, time: .standard),
            Date(julianDate: pass.set.julianDate).formatted(date: .omitted, time: .standard)
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
