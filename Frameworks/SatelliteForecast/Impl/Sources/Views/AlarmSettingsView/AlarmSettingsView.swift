//
//  AlarmSettingsView.swift
//  AlarmSettingsView
//
//  Created by Ben Lu on 8/20/21.
//

import SwiftUI
import Combine
@preconcurrency import CombineRex
@preconcurrency import CombineRextensions
import CoreLocation
@preconcurrency import SatelliteKit
import SatelliteForecast

public struct AlarmSettingsViewState: Equatable {
    public var scheduledPassNotifications: [ScheduledPassNotification] = []

    public init(scheduledPassNotifications: [ScheduledPassNotification] = []) {
        self.scheduledPassNotifications = scheduledPassNotifications
    }
}

public struct AlarmSettingsView: View {
    @ObservedObject var viewModel: ObservableViewModel<AlarmSettingsViewAction, AlarmSettingsViewState>

    public init(
        viewModel: ObservableViewModel<AlarmSettingsViewAction, AlarmSettingsViewState>
    ) {
        self.viewModel = viewModel
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
                    .foregroundColor(Color(UIColor.secondaryLabel))
            }

            if item.notification.timeOffset != 0 {
                Text(
                    AlarmSettingsView.alarmOffsetDescription(
                        timing: item.notification.timing,
                        offset: item.notification.timeOffset
                    )
                )
                .font(.caption)
                .foregroundColor(Color(UIColor.secondaryLabel))
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
            if viewModel.state.scheduledPassNotifications.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "bell.circle")
                        .font(.title)
                        .foregroundColor(Color(UIColor.secondaryLabel))
                    Text(
                    """
                    Your alarms will appear here. Schedule an alarm by tapping the \(Image(systemName: "bell")) inside a pass.
                    """,
                    bundle: .module
                    )
                    .foregroundColor(Color(UIColor.secondaryLabel))
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
                ForEach(viewModel.state.scheduledPassNotifications) { item in
                    itemView(item)
                }
                .onDelete { indexSet in
                    let ids = indexSet.map {
                        viewModel.state.scheduledPassNotifications[$0]
                    }
                    .reduce(
                        into: Set<String>(), {
                            $0.insert($1.id)
                        }
                    )

                    viewModel.dispatch(.deleteNotifications(ids: ids))
                }
            }
        }
        .listStyle(.insetGrouped)
        .animation(
            .spring(),
            value: viewModel.state.scheduledPassNotifications
        )
    }
    
    public var body: some View {
        alarmList.navigationTitle(Text("Alarms", bundle: .module, comment: "Noun, as in alarm clock."))
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

#if DEBUG
struct AlarmSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        let elements = try! Elements(
            raw: """
            ISS (ZARYA)
            1 25544U 98067A   21155.08058252  .00001489  00000-0  35252-4 0  9997
            2 25544  51.6446  47.5538 0003512  61.1482  91.5411 15.48950578286563
            """
        )
        // 2000 Broadway, Redwood City, CA 94063
        let observer = LatLonAlt(37.486743000691185, -122.22655970246515, 0)
        // Date range
        let startDate = Date(timeIntervalSinceReferenceDate: 20 * 365 * 86400)
        let julianDateRange = startDate.advanced(by: -60 * 60 * 2).julianDate...startDate.advanced(by: 60 * 60 * 30).julianDate
        let coarseSnapshots = try! SatelliteInfo(elements: elements).generateSnapshots(
            observer: observer,
            julianDateRange: julianDateRange,
            interval: 60
        )
        let passSnapshotsList = try! SatelliteInfo(elements: elements).findPasses(
            observer: observer,
            coarseSnapshots: coarseSnapshots
        )
        
        let items = passSnapshotsList.enumerated().map { index, passSnapshots in
            ScheduledPassNotification(
                id: "id_\(index)",
                notification: PassNotification(
                    pass: passSnapshots.pass,
                    satelliteName: "ISS (Zarya)",
                    category: .iss,
                    observer: observer,
                    timing: .rise,
                    timeOffset: Double.random(in: -7200...600)
                )
            )
        }
        
        AlarmSettingsView(
            viewModel: .mock(
                state: AlarmSettingsViewState(
                    scheduledPassNotifications: items
                )
            )
        )
    }
}
#endif
