//
//  LoggerMiddleware.swift
//  SatelliteForcast
//
//  Created by Ben Lu on 6/4/21.
//

import Foundation
import os
import SwiftRex

class LoggerMiddleware: Middleware {
    typealias InputActionType = AppAction // It wants to receive all possible app actions
    typealias OutputActionType = AppAction          // No action is generated from this Middleware
    typealias StateType = AppState        // It wants to read the whole app state

    var getState: GetState<AppState>!

    func receiveContext(getState: @escaping GetState<AppState>, output: AnyActionHandler<AppAction>) {
        self.getState = getState
    }

    func handle(action: AppAction, from dispatcher: ActionSource, afterReducer: inout AfterReducer) {
        let stateBefore: AppState = getState()
        let dateBefore = Date()

        afterReducer = .do {
            let stateAfter = self.getState()
            let dateAfter = Date()
            let source = "\(dispatcher.file):\(dispatcher.line) - \(dispatcher.function) | \(dispatcher.info ?? "")"

            os_log("action: \(String(describing: action)), from: \(source), before: \(String(describing: stateBefore)), after: \(String(describing: stateAfter)), dateBefore: \(dateBefore), dateAfter: \(dateAfter)")
        }
    }
}
