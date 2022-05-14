//
//  SkyChart+Wiring.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/30/22.
//

import CombineRex
import CombineRextensions
import SatelliteForecast
import SatelliteForecastImpl
import SwiftUI

extension SkyChartViewState: AppStateMappable {
    static func project(
        appState: AppState
    ) -> SkyChartViewState {
        return SkyChartViewState(
            julianDateOffset: appState.debugMenu.effectiveOffset,
            resources: appState.skyChartResources,
            backgroundSky: appState.backgroundSkyResources,
            elementsPropagatorResources: appState.elementsPropagatorResources
        )
    }

    static func apply(appState: inout AppState, state: SkyChartViewState) {
        appState.skyChartResources = state.resources
    }
}

extension ViewProducer where Context == SkyChartContext<EmptyView>, ProducedView == SkyChart<EmptyView> {
    static func skyChart<S: StoreType>(viewModel: S) -> ViewProducer where S.ActionType == AppAction, S.StateType == AppState {
        ViewProducer<Context, ProducedView> { context in
            return SkyChart<EmptyView>(
                viewModel: viewModel
                    .projection(
                        action: { AppAction.skyChart($0) },
                        state: SkyChartViewState.project(appState:)
                    )
                    .asObservableViewModel(
                        initialState: SkyChartViewState()
                    ),
                context: context,
                backgroundSkyViewProducer: .backgroundSky(viewModel: viewModel)
            )
        }
    }
}

extension ViewProducer where Context == SkyChartContext<ConstellationLabel>, ProducedView == SkyChart<ConstellationLabel> {
    static func skyChartForDetailedView<S: StoreType>(viewModel: S) -> ViewProducer where S.ActionType == AppAction, S.StateType == AppState {
        ViewProducer<Context, ProducedView> { context in
            return SkyChart<ConstellationLabel>(
                viewModel: viewModel
                    .projection(
                        action: { AppAction.skyChart($0) },
                        state: SkyChartViewState.project(appState:)
                    )
                    .asObservableViewModel(
                        initialState: SkyChartViewState()
                    ),
                context: context,
                backgroundSkyViewProducer: .backgroundSkyWithConstellationLabel(viewModel: viewModel)
            )
        }
    }
}
