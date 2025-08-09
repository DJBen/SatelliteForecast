import Foundation
import SatelliteForecast
@preconcurrency import SwiftRex
import StarryNight

extension Reducer where ActionType == AppAction, StateType == AppState {
    public static let initializerReducer = Reducer.reduce { action, state in
        switch action {
        case .initializeAllConstellations(let constellations):
            state.backgroundSkyResources.allConstellations = Array(constellations)
        default:
            break
        }
    }

}
