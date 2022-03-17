//
//  RealtimeSkyViewReducer.swift
//  RealtimeSkyView
//
//  Created by Ben Lu on 3/3/22.
//

import CombineRex

extension Reducer where ActionType == RealtimeSkyViewAction, StateType == RealtimeSkyViewResources {
    static let realtimeSkyReducer = Reducer.reduce { action, state in
        switch action {
        case .setRealtimeSkyViewActive(let isActive):
            state.isRealtimeSkyViewActive = isActive
        case .propagateCurrentEphemerides(_, observer: _, julianDate: _):
            state.isPropagatingEphemerides = true
        }
    }
}

extension Reducer where ActionType == RealtimeSkyViewOutput, StateType == RealtimeSkyViewResources {
    static let realtimeSkyOutputReducer = Reducer.reduce { action, state in
        switch action {
        case .propagatedCurrentEphemerides(
            let results,
            satellites: _,
            partialErrors: _,
            observer: _,
            julianDate: _
        ):
            state.results.merge(results, uniquingKeysWith: { $1 })
            state.isPropagatingEphemerides = false
        case .failedToPropagateCurrentEphemerides(error: _, observer: _, julianDate: _):
            state.isPropagatingEphemerides = false
        }
    }
}
