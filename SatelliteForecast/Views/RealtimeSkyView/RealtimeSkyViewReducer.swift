//
//  RealtimeSkyViewReducer.swift
//  RealtimeSkyView
//
//  Created by Ben Lu on 3/3/22.
//

import CombineRex

extension Reducer where ActionType == RealtimeSkyViewAction, StateType == RealtimeSkyViewState {
    static let realtimeSkyReducer = Reducer.reduce { action, state in
        switch action {
        case .setRealtimeSkyViewActive(let isActive):
            state.isRealtimeSkyViewActive = isActive
        case .propagateCurrentEphemerides(_, observer: _, julianDate: _):
            state.isPropagatingEphemerides = true
        }
    }
}

extension Reducer where ActionType == RealtimeSkyViewOutput, StateType == RealtimeSkyViewState {
    static let realtimeSkyReducer = Reducer.reduce { action, state in
        switch action {
        case .propagatedCurrentEphemerides(let results, tles: _, observer: _, julianDate: _):
            state.resources.results.merge(results, uniquingKeysWith: { $1 })
            state.isPropagatingEphemerides = false
        }
    }
}
