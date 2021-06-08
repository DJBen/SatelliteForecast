//
//  TimerMiddleware.swift
//  SatelliteForcast (iOS)
//
//  Created by Ben Lu on 6/7/21.
//

import Foundation
import Combine
import CombineRex

enum TimerAction {
    case start
    case tick(Date)
}

extension EffectMiddleware where
    InputActionType == TimerAction,
    OutputActionType == TimerAction,
    StateType == AppState,
    Dependencies == Void {

    static var timer: EffectMiddleware<TimerAction, TimerAction, AppState, Void> {
        EffectMiddleware<TimerAction, TimerAction, AppState, Void>
            .onAction { action, _, getState in
                switch action {
                case .start:
                    return .doNothing
//                    return Effect { context -> AnyPublisher<DispatchedAction<TimerAction>, Never> in
//                        Timer.publish(every: 1, on: .main, in: .default)
//                            .autoconnect()
//                            .map { DispatchedAction(TimerAction.tick($0)) }
//                            .eraseToAnyPublisher()
//                    }
                case .tick:
                    return .doNothing
                }
            }
    }
}
