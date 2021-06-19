//
//  PassViewReducer.swift
//  SatelliteForcast (iOS)
//
//  Created by Ben Lu on 6/17/21.
//

import Foundation
import SwiftRex

extension Reducer where ActionType == PassViewAction, StateType == Store.StateType {
    static let passViewReducer = Reducer.reduce { action, state in
        switch action {
        case .onAppear:
            break
        case .backToAllPasses:
            switch state.navigationState {
            case let .pass(noradIndex, selectedPassIndex: _):
                state.navigationState = .allPasses(noradIndex: noradIndex)
            default:
                break
            }
        }
    }
}

