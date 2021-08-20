//
//  NavigationReducer.swift
//  NavigationReducer
//
//  Created by Ben Lu on 8/8/21.
//

import Foundation
import os
import SwiftRex

fileprivate let logger = Logger(subsystem: "io.djben.navigation", category: "reducer")

extension Reducer where ActionType == NavigationAction, StateType == NavigationState {
    static let navigationReducer = Reducer.reduce { action, state in
        switch action {
        case .dismissLocationSettings:
            switch state {
            case .overview:
                break
            case .observer:
                state = .overview
            case .list,
                .allPasses(category: _, noradIndex: _),
                .pass(category: _, noradIndex: _, selectedPassIndex: _),
                .alarm:
                fatalError("Should not happen")
            }
            
        case .showAlertSettings:
            switch state {
            case .overview:
                state = .alarm
            case .alarm:
                break
            case .list,
                .allPasses(category: _, noradIndex: _),
                .pass(category: _, noradIndex: _, selectedPassIndex: _),
                .observer:
                fatalError("Should not happen")
            }
            
        case .dismissAlertSettings:
            switch state {
            case .overview:
                break
            case .alarm:
                state = .overview
            case .list,
                .allPasses(category: _, noradIndex: _),
                .pass(category: _, noradIndex: _, selectedPassIndex: _),
                .observer:
                fatalError("Should not happen")
            }
        }
    }
}
