//
//  AlarmSettingsView.swift
//  AlarmSettingsView
//
//  Created by Ben Lu on 8/20/21.
//

import SwiftUI
import Combine
import CombineRex
import CombineRextensions
import CoreLocation
import SatelliteKit
import SatelliteForecast
import SatelliteForecastImpl

public enum AlarmSettingsViewAction {
    case deleteNotifications(ids: Set<String>)
}

public struct AlarmSettingsViewState: Equatable {
    public struct Item: Equatable, Identifiable {
        public let id: String
        public let passNotification: PassNotification

        public init(id: String, passNotification: PassNotification) {
            self.id = id
            self.passNotification = passNotification
        }
    }
    
    public var notificationItems: [Item] = []

    public init(notificationItems: [AlarmSettingsViewState.Item] = []) {
        self.notificationItems = notificationItems
    }
}

public struct AlarmSettingsView: View {
    @ObservedObject var viewModel: ObservableViewModel<AlarmSettingsViewAction, AlarmSettingsViewState>

    public init(
        viewModel: ObservableViewModel<AlarmSettingsViewAction, AlarmSettingsViewState>
    ) {
        self.viewModel = viewModel
    }
    
    @ViewBuilder private func itemView(_ item: AlarmSettingsViewState.Item) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.passNotification.satelliteName)
                    .font(.headline)
                    .foregroundColor(Color(UIColor.label))
                
                Spacer()
                
                Text(Date(julianDate: item.passNotification.alertJulianDate).formatted())
                    .font(.subheadline)
                    .foregroundColor(Color(UIColor.secondaryLabel))
            }

            HStack {
                Text(CLLocation(item.passNotification.observer).coordinate.formattedString)
                    .font(.caption)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if item.passNotification.timeOffset != 0 {
                    Text(AlarmSettingsView.alarmOffsetDescription(timeInterval: item.passNotification.timeOffset))
                        .font(.caption)
                        .foregroundColor(Color(UIColor.secondaryLabel))
                }
            }
                        
            VStack(alignment: .leading, spacing: 4) {
                Text(AlarmSettingsView.passDescription(pass: item.passNotification.pass))
                    .font(.caption)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.primary)
                
                Text(AlarmSettingsView.passVisibilityDescription(pass: item.passNotification.pass))
                    .font(.caption)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.primary)
            }
        }
        .padding([.top, .bottom], 4)
    }
    
    @ViewBuilder var alarmList: some View {
        List {
            if viewModel.state.notificationItems.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "bell.circle")
                        .font(.title)
                        .foregroundColor(Color(UIColor.secondaryLabel))
                    Text(
                    """
                    Your alarms will appear here. You may swipe on a pass to schedule an alarm.
                    """
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
                ForEach(viewModel.state.notificationItems) { item in
                    itemView(item)
                }
                .onDelete { indexSet in
                    let ids = indexSet.map {
                        viewModel.state.notificationItems[$0]
                    }
                        .reduce(into: Set<String>(), { $0.insert($1.id) })

                    viewModel.dispatch(.deleteNotifications(ids: ids))
                }
            }
        }
        .listStyle(.insetGrouped)
        .animation(
            .spring(),
            value: viewModel.state.notificationItems
        )
    }
    
    public var body: some View {
        alarmList
        .navigationBarTitle("Alarms", displayMode: .inline)
        .toolbar {
            EditButton()
        }
    }
}

extension AlarmSettingsView {
    static func alarmOffsetDescription(timeInterval: TimeInterval) -> String {
        let beforeFormat = NSLocalizedString(
            "AlarmSettingsView.alarmOffsetDescription.before",
            tableName: nil,
            bundle: .main,
            value: "%@ before rise",
            comment: "The time interval description for each alarm in the alarm settings view"
        )

        let afterFormat = NSLocalizedString(
            "AlarmSettingsView.alarmOffsetDescription.after",
            tableName: nil,
            bundle: .main,
            value: "%@ after rise",
            comment: "The time interval description for each alarm in the alarm settings view"
        )

        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .short

        return String(
            format: timeInterval > 0 ? afterFormat : beforeFormat,
            formatter.string(from: abs(timeInterval))!
        )
    }

    static func passDescription(pass: Pass) -> String {
        let format = NSLocalizedString(
            "AlarmSettingsView.passDescription",
            tableName: nil,
            bundle: .main,
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
            bundle: .main,
            value: "Max visible elevation %.1f degrees.",
            comment: "The pass description for each alarm in the alarm settings view"
        )

        let daytimeFormat = NSLocalizedString(
            "AlarmSettingsView.passVisibilityDescription.daytime",
            tableName: nil,
            bundle: .main,
            value: "The pass occurs during daylight with a max elevation of %.1f degrees.",
            comment: "The pass description for each alarm in the alarm settings view"
        )

        let unlitFormat = NSLocalizedString(
            "AlarmSettingsView.passVisibilityDescription.unlit",
            tableName: nil,
            bundle: .main,
            value: "The pass is not illuminated with a max elevation of %.1f degrees.",
            comment: "The pass description for each alarm in the alarm settings view"
        )

        switch pass.visibility {
        case .visible:
            return String(
                format: visibleFormat,
                pass.highestIlluminatedElevation
            )
        case .daylight:
            return String(
                format: daytimeFormat,
                pass.transit.elev
            )
        case .unlit:
            return String(
                format: unlitFormat,
                pass.transit.elev
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
        let observer = LatLonAlt(lat: 37.486743000691185, lon: -122.22655970246515, alt: 0)
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
            AlarmSettingsViewState.Item(
                id: "id_\(index)",
                passNotification: PassNotification(
                    pass: passSnapshots.pass,
                    satelliteName: "ISS (Zarya)",
                    category: nil,
                    observer: observer,
                    timeOffset: Double.random(in: -7200...600)
                )
            )
        }
        
        AlarmSettingsView(
            viewModel: .mock(
                state: AlarmSettingsViewState(
                    notificationItems: items
                )
            )
        )
    }
}
#endif
