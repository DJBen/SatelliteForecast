//
//  TimerMiddleware.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/7/21.
//

import Foundation
import Combine
import CombineRex

enum TimerAction {
    case start
    case tick(Double)
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
                    return Effect { context -> AnyPublisher<DispatchedAction<TimerAction>, Never> in
                        Timer.publish(every: 10, on: .current, in: .default)
                            .autoconnect()
                            .map {
                                DispatchedAction(TimerAction.tick($0.julianDate))
                            }
                            .eraseToAnyPublisher()
                    }
                case .tick:
                    return .doNothing
                }
            }
    }
}
