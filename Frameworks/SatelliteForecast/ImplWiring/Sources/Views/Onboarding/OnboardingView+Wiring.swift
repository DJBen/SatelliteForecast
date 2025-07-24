//
//  OnboardingView+Wiring.swift
//  SatelliteForecast
//
//  Created by Copilot on 7/22/25.
//

@preconcurrency import CombineRex
@preconcurrency import CombineRextensions
import SatelliteForecast
import SatelliteForecastImpl

extension OnboardingViewState: AppStateMappable {
    public static func project(appState: AppState) -> OnboardingViewState {
        appState.onboardingState
    }

    public static func apply(appState: inout AppState, state: OnboardingViewState) {
        appState.onboardingState = state
    }
}

extension ViewProducer where Context == Void, ProducedView == OnboardingView {
    public static func onboarding<S: StoreType>(viewModel: S) -> ViewProducer where S.ActionType == AppAction, S.StateType == AppState {
        ViewProducer<Context, ProducedView> { context in
            OnboardingView {
                viewModel.dispatch(.onboarding(.complete))
            }
        }
    }
}
