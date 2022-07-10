//
//  DetailedPassViewReducer.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 5/14/22.
//

import SatelliteForecast
import SwiftRex

extension Reducer where ActionType == DetailedPassViewAction, StateType == DetailedPassViewState {
    public static let detailedPassViewReducer = Reducer.reduce { action, state in
        switch action {
        case .dismissModal:
            state.showsDetailedPassView = false
        }
    }
}
