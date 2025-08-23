//
//  DebugMenuMiddleware.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 7/25/21.
//

import Foundation
import Combine
@preconcurrency import CombineRex
@preconcurrency import SatelliteKit
import SatelliteForecast

public struct DebugMenuMiddlewareDependencies {
    public let dateProvider: () -> Date

    public init(dateProvider: @escaping () -> Date) {
        self.dateProvider = dateProvider
    }
}

public typealias DebugMenuEffectMiddleware = EffectMiddleware<DebugMenuAction, AppAction, AppState, DebugMenuMiddlewareDependencies>

extension EffectMiddleware where
    InputActionType == DebugMenuAction,
    OutputActionType == AppAction,
    StateType == AppState,
    Dependencies == Void {

    public static var debugMenu: MiddlewareReader<DebugMenuMiddlewareDependencies, DebugMenuEffectMiddleware> {
        DebugMenuEffectMiddleware.onAction { action, _, getState in
            switch action {
            case .toggleDebugMenu(_):
                return .doNothing
            case .toggleFreezeTime(_):
                return .doNothing
            case .toggleMockedOffset(_):
                return .doNothing
            case .setMockedDateOffset(_):
                return .doNothing
            case .toggleRapidNotificationDelivery(_):
                return .doNothing
            case .fetchNotifications:
                return .sequence([
                    .notification(.fetchPendingNotificationRequests),
                    .notification(.fetchDeliveredNotifications)
                ])
            case let .triggerPassDeepLink(category, noradIndex):
                return Effect { context -> AnyPublisher<DispatchedAction<AppAction>, Never> in
                    let subject = PassthroughSubject<DispatchedAction<AppAction>, Never>()
                    guard let observer = getState().locationResources.location.map(LatLonAlt.init) else {
                        subject.send(completion: .finished)
                        return subject.eraseToAnyPublisher()
                    }

                    DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                        subject.send(DispatchedAction(.notification(
                            .deepLink(
                                category: category,
                                noradIndex: noradIndex,
                                observer: observer,
                                passIdentifier: "test_\(UUID().uuidString)"
                            )
                        )))
                        subject.send(completion: .finished)
                    }

                    return subject.eraseToAnyPublisher()
                }
            case .resetOnboarding:
                // Reset both main onboarding and AllPasses onboarding
                UserDefaults.standard.set(false, forKey: "hasCompletedAllPassesOnboarding")
                return .just(.onboarding(.reset))
            case .resetMainOnboarding:
                // Reset only the main onboarding
                return .just(.onboarding(.reset))
            case .resetAllPassesOnboarding:
                // Reset only the AllPasses onboarding
                UserDefaults.standard.set(false, forKey: "hasCompletedAllPassesOnboarding")
                return .doNothing
            case .resetSkyChartTutorial:
                // Reset only the sky chart tutorial
                UserDefaults.standard.set(false, forKey: "hasCompletedSkyChartTutorial")
                return .doNothing
            }
        }
    }
}
