//
//  LocationSettingsView+Wiring.swift
//  SatelliteForecastImplWiring
//
//  Created by Ben Lu on 4/7/22.
//

@preconcurrency import CombineRex
@preconcurrency import CombineRextensions
import SatelliteForecastImpl

extension LocationSettingsViewState: AppStateMappable {
    public static func project(appState: AppState) -> LocationSettingsViewState {
        LocationSettingsViewState(
            locationSelection: appState.locationResources.selection,
            currentLocation: appState.locationResources.currentLocation,
            currentLocationPlacemark: appState.locationResources.currentLocationPlacemark,
            autocompletionResult: appState.locationResources.autocompletionResult
        )
    }

    public static func apply(appState: inout AppState, state: LocationSettingsViewState) {
    }
}

extension ViewProducer where Context == Void, ProducedView == LocationSettingsView {
    public static func locationSettings<S: StoreType>(viewModel: S) -> ViewProducer where S.ActionType == AppAction, S.StateType == AppState {
        ViewProducer<Context, ProducedView> { context in
            LocationSettingsView(
                viewModel: viewModel
                    .projection(
                        action: { AppAction.location($0) },
                        state: LocationSettingsViewState.project(appState:)
                    )
                    .asObservableViewModel(initialState: .init(), emitsValue: .whenDifferent)
            )
        }
    }
}
