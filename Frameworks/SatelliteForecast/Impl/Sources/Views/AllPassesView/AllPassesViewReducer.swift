//
//  AllPassesViewReducer.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 6/17/21.
//

import Foundation
@preconcurrency import SwiftRex
@preconcurrency import SatelliteKit
@preconcurrency import CombineRex
import Combine
import os
import StarryNight
import SatelliteForecast
import UIKit
import SwiftUI

extension Reducer where ActionType == AllPassesViewAction, StateType == AppState {
    public static let allPassesViewReducer = Reducer.reduce { action, state in
        switch action {
        case .calculatePasses:
            break
        case .recalculatePasses:
            break
        case .scheduleNotification(_, _):
            break
        case .unscheduleNotification(_):
            break
        case .deeplinkToLocationSelection:
            state.navigationState.tab = .settings
        case .showLocationSettings:
            break
        case .showOnboarding(let show):
            state.navigationState.listNavigation.showsOnboarding = show
        case .completeOnboarding:
            // Mark onboarding as completed in user defaults
            UserDefaults.standard.set(true, forKey: "hasCompletedAllPassesOnboarding")
            state.navigationState.listNavigation.showsOnboarding = false
        }
    }
}

extension EffectMiddleware where InputActionType == AllPassesViewAction, OutputActionType == ElementsPropagatorAction, StateType == Void, Dependencies == Void {
    public static var allPassesViewToElementsPropagator: EffectMiddleware<AllPassesViewAction, ElementsPropagatorAction, Void, Void> {
        EffectMiddleware<AllPassesViewAction, ElementsPropagatorAction, Void, Void>.onAction { (action, _, getState) -> Effect<Void, ElementsPropagatorAction> in
            switch action {
            case .calculatePasses(let calculatePassesParams):
                return .just(.calculatePasses(calculatePassesParams))
            case .recalculatePasses(let calculatePassesParams):
                return .just(.recalculatePasses(calculatePassesParams))
            case .scheduleNotification(_, _):
                return .doNothing
            case .unscheduleNotification(_):
                return .doNothing
            case .deeplinkToLocationSelection:
                return .doNothing
            case .showLocationSettings:
                return .doNothing
            case .showOnboarding(_):
                return .doNothing
            case .completeOnboarding:
                return .doNothing
            }
        }
    }
}

fileprivate let logger = Logger(subsystem: "io.djben.allPassesView", category: "middleware")

extension EffectMiddleware where InputActionType == AllPassesViewAction, OutputActionType == NotificationAction, StateType == AppState, Dependencies == Void {
    public static var allPassesViewToNotification: EffectMiddleware<AllPassesViewAction, NotificationAction, AppState, Void> {
        EffectMiddleware<AllPassesViewAction, NotificationAction, AppState, Void>.onAction { (action, _, getState) -> Effect<Void, NotificationAction> in
            switch action {
            case .calculatePasses(_):
                return .doNothing
            case .recalculatePasses(_):
                return .doNothing
            case .scheduleNotification(let passNotification, let passSnapshots):
                return .just(.generatePreviewAndScheduleNotification(passNotification, passSnapshots: passSnapshots))
            case .unscheduleNotification(let pass):
                return .just(.removePreviewAndUnscheduleNotification(pass))
            case .deeplinkToLocationSelection:
                return .doNothing
            case .showLocationSettings:
                UIApplication.shared.open(
                    URL(string: UIApplication.openSettingsURLString)!,
                    options: [:],
                    completionHandler: nil
                )
                return .doNothing
            case .showOnboarding(_):
                return .doNothing
            case .completeOnboarding:
                return .doNothing
            }
        }
    }
}
