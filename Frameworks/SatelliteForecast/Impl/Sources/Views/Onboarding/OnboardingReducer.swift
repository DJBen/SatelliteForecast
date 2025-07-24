//
//  OnboardingReducer.swift
//  SatelliteForecast
//
//  Created by Copilot on 7/22/25.
//

import Foundation
@preconcurrency import SwiftRex

extension Reducer where ActionType == OnboardingAction, StateType == OnboardingViewState {
    public static let onboardingReducer = Reducer.reduce { action, state in
        switch action {
        case .complete:
            state.hasCompletedOnboarding = true
            // Persist the onboarding completion
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        case .pageChanged(let page):
            state.currentPage = page
        case .reset:
            state.hasCompletedOnboarding = false
            // Remove the onboarding completion from storage
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        }
    }
}
