//
//  CoreLocationReducer.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/4/21.
//

import Foundation
import SwiftRex

extension Reducer where ActionType == LocationAction, StateType == LocationState {
    static let locationReducer = Reducer.reduce { action, state in
        switch action {
        case .requestAuthorization:
            break
        case .requestReverseGeocoding(_):
            break
        case .requestAutoCompletion(_):
            break
        case let .selectLocation(selection):
            if selection == .currentLocation && state.currentLocation == nil {
                break
            }
            state.selection = selection
        case let .authorizationDidChange(authorizationStatus):
            state.authorizationStatus = authorizationStatus
        case let .locationChanged(location):
            state.currentLocation = location
            state.currentLocationPlacemark = nil
        case let .reverseGeocodingFinished(result):
            switch result {
            case let .success(placemarks):
                state.currentLocationPlacemark = placemarks.first
            case .failure(_):
                break
            }
        case let .autocompletionFinished(result):
            state.autocompletionResult = result
        }
    }
}
