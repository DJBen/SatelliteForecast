//
//  AppDelegateMiddleware.swift
//  AppDelegateMiddleware
//
//  Created by Ben Lu on 8/18/21.
//

import Foundation
import Combine
import CombineRex
import os
import SatelliteKit

fileprivate let logger = Logger(subsystem: "io.djben.appDelegate", category: "middleware")

extension EffectMiddleware where
    InputActionType == AppDelegateAction,
    OutputActionType == AppAction,
    StateType == AppState,
    Dependencies == Void {

    static var appDelegate: EffectMiddleware<AppDelegateAction, AppAction, AppState, Void> {
        EffectMiddleware<AppDelegateAction, AppAction, AppState, Void>
            .onAction { action, _, getState in
                switch action {
                case let .didFinishLaunchingWithOptions(launchOptions):
                    return .sequence([
                        .backgroundTask(.registerHandleCalculatingUpcomingPasses),
                        .notification(.loadNotificationsFromPersistenceStorage),
                        .notification(.registerNotifications),
                    ])
                case .didRegisterForRemoteNotificationsWithDeviceToken(_):
                    return .doNothing
                case let .scenePhaseDidChange(phase):
                    switch phase {
                    case .active:
                        logger.debug("App becomes active")
                        
                        return .just(.notification(.loadNotificationsFromPersistenceStorage))
                    case .inactive:
                        logger.debug("App becomes inactive")
                        return .doNothing
                    case .background:
                        logger.debug("App enters background")
                        
                        return .sequence([
                            .backgroundTask(.submitHandleCalculatingUpcomingPasses),
                            .notification(.saveNotificationsToPersistenceStorage(getState().notificationState.scheduledPassNotifications))
                        ])
                    @unknown default:
                        return .doNothing
                    }
                }
            }
    }
}
