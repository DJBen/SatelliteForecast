//
//  TLEPropagatorReducer.swift
//  SatelliteForcast (iOS)
//
//  Created by Ben Lu on 6/7/21.
//

import Foundation
import SwiftRex

extension Reducer where ActionType == TLEPropagatorAction, StateType == Store.StateType {
    static let tlePropagatorReducer = Reducer.reduce { action, state in
        switch action {
        case let .foundPasses(passInformation, searchDateRange, noradIndex):
            state.skyChartState.skyReferenceDate = passInformation.compactMap { $0.risesAt ?? $0.setsAt }.first ?? Date()
            state.skyChartState.passInformation = passInformation
        case let .propagatedSnapshots(satelliteSnapshots, noradIndex):
            state.allSnapshots[noradIndex] = satelliteSnapshots
        }
    }
}
