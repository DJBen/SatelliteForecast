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
            if let index = index {
                state.navigationState.selectPassIndex(index)
            } else {
                state.navigationState.deselectPassIndex()
            }
        }
    }
}

