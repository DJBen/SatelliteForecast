//
//  RealtimeSkyView+Wiring.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/4/22.
//

import BTree
import CombineRex
import CombineRextensions
import SatelliteForecastCore
import SatelliteKit

extension RealtimeSkyViewState: AppStateMappable {
    static func project(appState: AppState) -> RealtimeSkyViewState {
        RealtimeSkyViewState(
            resources: RealtimeSkyViewResources.project(appState: appState),
            satellites: {
                guard let values = appState.tleLoader.info[.active]?.content?.values else {
                    return nil
                }
                return Array(values)
            }(),
            observer: appState.locationState.location.map(LatLonAlt.init(location:)),
            julianDateOffset: appState.debugMenu.effectiveOffset
        )
    }

    static func apply(appState: inout AppState, state: RealtimeSkyViewState) {

    }
}

extension RealtimeSkyViewResources: AppStateMappable {
    static func project(appState: AppState) -> RealtimeSkyViewResources {
        appState.realtimeSkyResources
    }

    static func apply(appState: inout AppState, state: RealtimeSkyViewResources) {
        appState.realtimeSkyResources = state
    }
}

extension ViewProducer where Context == RealtimeSkyViewContext, ProducedView == RealtimeSkyViewImpl {
    static func realtimeSky<S: StoreType>(
        viewModel: S
    ) -> ViewProducer where
    S.ActionType == AppAction,
    S.StateType == AppState {
        ViewProducer<Context, ProducedView> { context in
            RealtimeSkyViewImpl(
                viewModel: viewModel.projection(
                    action: AppAction.realtimeSky,
                    state: RealtimeSkyViewState.project(appState:)
                )
                .asObservableViewModel(
                    initialState: .init(),
                    emitsValue: .whenDifferent
                ),
                context: context,
                backgroundSkyViewProducer: .backgroundSky(viewModel: viewModel)
            )
        }
    }
}
