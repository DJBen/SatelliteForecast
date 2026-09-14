import SwiftUI
@preconcurrency import CombineRex
import CombineRextensions
import SatelliteForecast
import SatelliteForecastImpl

/// Temporary subscription boundary for shared location and notification services.
/// Search queries and screen navigation never enter the legacy store.
public struct LegacySettingsView: SettingsOverviewView {
    @ObservedObject var data: ObservableViewModel<AppAction, SettingsData>
    let settings: AppSettings

    public var body: some View {
        SettingsOverviewViewImpl(
            settings: settings,
            observerCellViewProducer: { ObserverCell(resources: data.state.location) },
            locationSettingsViewProducer: {
                LocationSettingsView(state: .init(
                    locationSelection: data.state.location.selection,
                    currentLocation: data.state.location.currentLocation,
                    currentLocationPlacemark: data.state.location.currentLocationPlacemark
                ), selectLocation: { data.dispatch(.location(.selectLocation($0))) })
            },
            alarmSettingsCellProducer: { AlarmSettingsCell(numberOfAlerts: data.state.alarms.count) },
            alarmSettingsViewProducer: {
                AlarmSettingsView(notifications: Array(data.state.alarms),
                    deleteNotifications: { data.dispatch(.notification(.cancelNotifications(ids: $0))) })
            }
        )
    }
}

struct SettingsData: Equatable {
    var location: LocationResources = .init()
    var alarms: Set<ScheduledPassNotification> = []
}

extension ViewProducer where Context == Void, ProducedView == LegacySettingsView {
    public static func settingsOverview<S: StoreType>(viewModel: S, settings: AppSettings) -> ViewProducer
    where S.ActionType == AppAction, S.StateType == AppState {
        ViewProducer { _ in
            LegacySettingsView(data: viewModel.projection(action: { $0 }, state: {
                SettingsData(location: $0.locationResources, alarms: $0.notificationResources.scheduledPassNotifications)
            }).asObservableViewModel(initialState: .init(), emitsValue: .whenDifferent), settings: settings)
        }
    }
}
