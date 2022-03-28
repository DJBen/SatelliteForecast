//
//  MenuView+Wiring.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/28/22.
//

import SatelliteForecastCore
import SatelliteKit
import SwiftUI
import CombineRex
import CombineRextensions

extension ViewProducer where Context == MenuViewContext, ProducedView == MenuView {
    static func menuView<S: StoreType>(
        viewModel: S
    ) -> ViewProducer<MenuViewContext, MenuView> where S.ActionType == AppAction, S.StateType == AppState {
        ViewProducer<Context, ProducedView> { context in
            MenuView(
                context: context,
                listViewProducer: ViewProducer<SatelliteListViewContext, SatelliteListView>
                    .satelliteListView(viewModel: viewModel),
                singleSatelliteWrappingViewProducer: ViewProducer<SingleSatelliteWrappingViewContext, SingleSatelliteWrappingView>.singleSatelliteWrappingView(viewModel: viewModel),
                observerCellViewProducer: ViewProducer<Void, ObserverCell>.observerCell(viewModel: viewModel),
                locationSettingsViewProducer: ViewProducer<Void, LocationSettingsView>.locationSettings(viewModel: viewModel),
                alarmSettingsCellProducer: ViewProducer<Void, AlarmSettingsCell>.alarmSettingsCell(viewModel: viewModel),
                alarmSettingsViewProducer: ViewProducer<Void, AlarmSettingsView>.alarmSettingsView(viewModel: viewModel)
            )
        }
    }
}
