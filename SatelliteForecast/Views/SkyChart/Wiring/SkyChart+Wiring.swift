//
//  SkyChart+Wiring.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/30/22.
//

import CombineRex
import CombineRextensions
import SwiftUI

extension ViewProducer where Context == SkyChartContext, ProducedView == SkyChart {
    static func skyChart<S: StoreType>(viewModel: S) -> ViewProducer where S.ActionType == AppAction, S.StateType == AppState {
        ViewProducer<Context, ProducedView> { context in
            return SkyChart(
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
