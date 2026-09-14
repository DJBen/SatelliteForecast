//
//  CoreLocationReducer.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 6/4/21.
//

import Foundation
import SatelliteForecast
@preconcurrency import SwiftRex

extension Reducer where ActionType == LocationAction, StateType == LocationState {
    public static let locationReducer = Reducer.reduce { action, state in
        switch action {
        case .requestAuthorization:
            break
        case .requestReverseGeocoding(_):
            break
        case let .selectLocation(selection):
            if selection == .currentLocation && state.resources.currentLocation == nil {
                break
            }
            state.resources.selection = selection

        }
    }

}

extension Reducer where ActionType == LocationOutput, StateType == LocationState {
    public static let locationOutputReducer = Reducer.reduce { action, state in
        switch action {
        case let .authorizationDidChange(authorizationStatus):
            state.resources.authorizationStatus = authorizationStatus
        case let .locationChanged(location):
            state.resources.currentLocation = location
            state.resources.currentLocationPlacemark = nil
        case let .reverseGeocodingFinished(result):
            switch result {
            case let .success(placemarks):
                state.resources.currentLocationPlacemark = placemarks.first
            case .failure(_):
                break
            }
        }
    }
}
