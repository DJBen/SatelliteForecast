@preconcurrency import CombineRex
import CombineRextensions
import SatelliteForecast
import SatelliteForecastImpl

// Temporary composition boundary for destinations still backed by SwiftRex.
// The Settings screen itself only receives native state and view closures.
extension ViewProducer where Context == Void, ProducedView == SettingsOverviewViewImpl {
    public static func settingsOverview<S: StoreType>(
        viewModel: S,
        settings: AppSettings
    ) -> ViewProducer where S.ActionType == AppAction, S.StateType == AppState {
        ViewProducer { _ in
            SettingsOverviewViewImpl(
                settings: settings,
                observerCellViewProducer: { ViewProducer<Void, ObserverCell>.observerCell(viewModel: viewModel).view() },
                locationSettingsViewProducer: { ViewProducer<Void, LocationSettingsView>.locationSettings(viewModel: viewModel).view() },
                alarmSettingsCellProducer: { ViewProducer<Void, AlarmSettingsCell>.alarmSettingsCell(viewModel: viewModel).view() },
                alarmSettingsViewProducer: { ViewProducer<Void, AlarmSettingsView>.alarmSettingsView(viewModel: viewModel).view() }
            )
        }
    }
}
