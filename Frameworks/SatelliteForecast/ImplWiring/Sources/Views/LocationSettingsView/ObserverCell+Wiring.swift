//
//  ObserverCell+Wiring.swift
//  SatelliteForecastImplWiring
//
//  Created by Ben Lu on 4/7/22.
//

@preconcurrency import CombineRex
@preconcurrency import CombineRextensions
import SatelliteForecast
import SatelliteForecastImpl

extension ObserverCellState: AppStateMappable {
    public static func project(appState: AppState) -> ObserverCellState {
        ObserverCellState(
            locationResources: appState.locationResources
        )
    }

    public static func apply(appState: inout AppState, state: ObserverCellState) {

    }
}

extension ViewProducer where Context == Void, ProducedView == ObserverCell {
    public static func observerCell<S: StoreType>(viewModel: S) -> ViewProducer where S.ActionType == AppAction, S.StateType == AppState {
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
