//
//  LoggerMiddleware.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/4/21.
//

import Foundation
import os
import SwiftRex

fileprivate let logger = Logger(subsystem: "io.djben.logger", category: "middleware")

class LoggerMiddleware: Middleware {
    typealias InputActionType = AppAction
    typealias OutputActionType = AppAction
    typealias StateType = AppState

    var getState: GetState<AppState>!

    func receiveContext(getState: @escaping GetState<AppState>, output: AnyActionHandler<AppAction>) {
        self.getState = getState
    }

    func handle(action: AppAction, from dispatcher: ActionSource, afterReducer: inout AfterReducer) {
        afterReducer = .do {
            logger.info("\(String(describing: action))")
        }
    }
}
