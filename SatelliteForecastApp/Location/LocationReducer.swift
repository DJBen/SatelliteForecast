//
//  CoreLocationReducer.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/4/21.
//

import Foundation
import SwiftRex

extension Reducer where ActionType == LocationAction, StateType == AppState {
    static let locationReducer = Reducer.reduce { action, state in
        switch action {
        case .requestAuthorization:
            break
        case .requestReverseGeocoding(_):
            break
        case .requestAutoCompletion(_):
            break
        case let .selectLocation(selection):
            if selection == .currentLocation && state.locationState.currentLocation == nil {
                break
            }
            state.locationState.selection = selection
            if state.navigationState.observerNavigation.enabled {
                state.navigationState.observerNavigation.enabled = false
            }
        case let .authorizationDidChange(authorizationStatus):
            state.locationState.authorizationStatus = authorizationStatus
        case let .locationChanged(location):
            state.locationState.currentLocation = location
            state.locationState.currentLocationPlacemark = nil
        case let .reverseGeocodingFinished(result):
            switch result {
            case let .success(placemarks):
                state.locationState.currentLocationPlacemark = placemarks.first
            case .failure(_):
                break
            }
        case let .autocompletionFinished(result):
            state.locationState.autocompletionResult = result
        case .persistLocation(_):
            break
        }
    }
}
