//
//  SingleSatelliteWrappingView+Wiring.swift
//  SatelliteForecastImplWiring
//
//  Created by Ben Lu on 4/7/22.
//

@preconcurrency import CombineRex
@preconcurrency import CombineRextensions
import SatelliteForecastImpl

extension SingleSatelliteWrappingViewState: AppStateMappable {
    public static func project(appState: AppState) -> SingleSatelliteWrappingViewState {
        return SingleSatelliteWrappingViewState(
            elementsLoader: appState.elementsLoader
        )
    }

    public static func apply(appState: inout AppState, state: SingleSatelliteWrappingViewState) {

    }
}

extension ViewProducer where Context == SingleSatelliteWrappingViewContext, ProducedView == SingleSatelliteWrappingView {
    public static func singleSatelliteWrappingView<S: StoreType>(viewModel: S) -> ViewProducer where S.ActionType == AppAction, S.StateType == AppState {
        ViewProducer<Context, ProducedView> { context in
            SingleSatelliteWrappingView(
                viewModel: viewModel.projection(
                    action: AppAction.singleSatelliteWrappingView,
                    state: SingleSatelliteWrappingViewState.project(appState:)
                )
                .asObservableViewModel(initialState: .init(), emitsValue: .whenDifferent),
                context: context,
                allPassesViewProducer: ViewProducer<AllPassesViewContext, AllPassesView>
                    .allPassesView(viewModel: viewModel)
            )
        }
    }
}
