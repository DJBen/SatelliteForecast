//
//  PassView+Wiring.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/30/22.
//

@preconcurrency import CombineRex
@preconcurrency import CombineRextensions
import SatelliteForecast
import SatelliteForecastImpl

extension PassViewState: AppStateMappable {
    public static func project(appState: AppState) -> PassViewState {
        return PassViewState(
            scheduledPassNotifications: appState.notificationResources.scheduledPassNotifications,
            showAlarmConfigurationModal: appState.navigationState.listNavigation.showAlarmConfigurationModal,
            showsDetailPassView: appState.navigationState.listNavigation.showsDetailPassView,
        )
    }
    
    public static func apply(appState: inout AppState, state: PassViewState) {
        appState.navigationState.listNavigation.showAlarmConfigurationModal = state.showAlarmConfigurationModal
        appState.navigationState.listNavigation.showsDetailPassView = state.showsDetailPassView
    }
}

extension ViewProducer where Context == PassViewContext, ProducedView == PassView {
    public static func passView<S: StoreType>(viewModel: S) -> ViewProducer where S.ActionType == AppAction, S.StateType == AppState {
        ViewProducer<PassViewContext, PassView> { context in
            PassView(
                viewModel: viewModel
                    .projection(
                        action: AppAction.passView,
                        state: PassViewState.project(appState:)
                    )
                    .asObservableViewModel(initialState: .init(), emitsValue: .whenDifferent),
                context: context,
                elevationGraphProducer: ViewProducer<SatelliteElevationGraphContext, SatelliteElevationGraph>
                    .satelliteElevationGraph(viewModel: viewModel),
                skyChartProducer: ViewProducer<SkyChartContext, SkyChart>
                    .skyChart(viewModel: viewModel),
                passAlarmSettingsProducer: ViewProducer<PassAlarmSettingsModalViewContext, PassAlarmSettingsModalView>.passAlarmSettings(viewModel: viewModel),
                detailedPassViewProducer: ViewProducer<DetailPassViewContext, DetailedPassView>.detailedPassView(viewModel: viewModel)
            )
        }
    }
}
