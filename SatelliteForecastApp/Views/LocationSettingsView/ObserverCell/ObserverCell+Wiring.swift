//
//  ObserverCell+Wiring.swift
//  SatelliteForecastApp
//
//  Created by Ben Lu on 4/7/22.
//

import CombineRex
import CombineRextensions
import SatelliteForecastImpl

extension ObserverCellState: AppStateMappable {
    static func project(appState: AppState) -> ObserverCellState {
        ObserverCellState(
            locationResources: appState.locationResources
        )
    }

    static func apply(appState: inout AppState, state: ObserverCellState) {

    }
}

extension ViewProducer where Context == Void, ProducedView == ObserverCell {
    static func observerCell<S: StoreType>(viewModel: S) -> ViewProducer where S.ActionType == AppAction, S.StateType == AppState {
        ViewProducer<Context, ProducedView> { context in
            ObserverCell(
                viewModel: viewModel.projection(
                    action: AppAction.observerCell,
                    state: ObserverCellState.project(appState:)
                )
                .asObservableViewModel(initialState: .init(), emitsValue: .whenDifferent)
            )
        }
    }
}
