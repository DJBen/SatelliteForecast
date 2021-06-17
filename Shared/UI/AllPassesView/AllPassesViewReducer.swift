//
//  AllPassesViewReducer.swift
//  SatelliteForcast (iOS)
//
//  Created by Ben Lu on 6/17/21.
//

import Foundation
import SwiftRex

extension Reducer where ActionType == AllPassesViewAction, StateType == Store.StateType {
    static let allPassesViewReducer = Reducer.reduce { action, state in
        switch action {
        case .onAppear:
            break
        case let .selectPass(index):
            switch state.navigationState {
            case let .allPasses(noradIndex):
                if let index = index {
                    state.navigationState = .pass(noradIndex: noradIndex, selectedPassIndex: index)
                }
            case let .pass(noradIndex, selectedPassIndex):
                if index == nil {
                    state.navigationState = .allPasses(noradIndex: noradIndex)
                }
            default:
                break
            }
        }
    }
}

