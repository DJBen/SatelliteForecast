//
//  SatelliteListViewReducer.swift
//  SatelliteForcast
//
//  Created by Ben Lu on 6/5/21.
//

import Foundation
import SwiftRex

extension Reducer where ActionType == SatelliteListViewAction, StateType == Store.StateType {
    static let satelliteListViewReducer = Reducer.reduce { action, state in
        switch action {
        case .onAppear:
            break
        case let .selectSatellite(noradIndex: noradIndex):
            state.selectedSatelliteNoradIndex = noradIndex
        }
    }
}
