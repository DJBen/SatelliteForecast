//
//  BackgroundSkyView+Wiring.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/4/22.
//

@preconcurrency import CombineRex
@preconcurrency import CombineRextensions
import SatelliteForecast
import SatelliteForecastImpl
import SwiftUI

extension BackgroundSkyViewState: AppStateMappable {
    public static func project(appState: AppState) -> BackgroundSkyViewState {
        BackgroundSkyViewState(
            resources: appState.backgroundSkyResources
        )
    }

    public static func apply(appState: inout AppState, state: BackgroundSkyViewState) {
        appState.backgroundSkyResources = state.resources
    }
}

extension BackgroundSkyResources: AppStateMappable {
    public static func project(appState: AppState) -> BackgroundSkyResources {
        appState.backgroundSkyResources
    }

    public static func apply(appState: inout AppState, state: BackgroundSkyResources) {
        appState.backgroundSkyResources = state
    }
}

extension ViewProducer where Context == BackgroundSkyViewContext<EmptyView, EmptyView>, ProducedView == BackgroundSkyView<EmptyView, EmptyView> {
    static func backgroundSky<S: StoreType>(
        viewModel: S
    ) -> ViewProducer where
    S.ActionType == AppAction,
    S.StateType == AppState {
        ViewProducer<Context, ProducedView> { context in
            BackgroundSkyView<EmptyView, EmptyView>(
                viewModel: viewModel.projection(
                    action: AppAction.backgroundSky,
                    state: BackgroundSkyViewState.project(appState:)
                )
                .asObservableViewModel(
                    initialState: .init(),
                    emitsValue: .whenDifferent
                ),
                context: context
            )
        }
    }
}

extension ViewProducer where Context == BackgroundSkyViewContext<ConstellationLabel, DetailedPassViewBackgroundAnnotationView>, ProducedView == BackgroundSkyView<ConstellationLabel, DetailedPassViewBackgroundAnnotationView> {
    static func backgroundSkyWithConstellationLabel<S: StoreType>(
        viewModel: S
    ) -> ViewProducer where
    S.ActionType == AppAction,
    S.StateType == AppState {
        ViewProducer<Context, ProducedView> { context in
            BackgroundSkyView<ConstellationLabel, DetailedPassViewBackgroundAnnotationView>(
                viewModel: viewModel.projection(
                    action: AppAction.backgroundSky,
                    state: BackgroundSkyViewState.project(appState:)
                )
                .asObservableViewModel(
                    initialState: .init(),
                    emitsValue: .whenDifferent
                ),
                context: context
            )
        }
    }
}
