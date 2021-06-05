//
//  Store.swift
//  SatelliteForcast
//
//  Created by Ben Lu on 6/4/21.
//

import SatelliteKit
import SatelliteForcastCore
import SwiftRex
import CombineRex

struct AppState: Equatable {
    var satellites: Loadable<[Satellite]>
    var observerCoordinate: LatLonAlt

    var allSnapshots: [String: [SatelliteSnapshot]] = [:]
    var currentSatelliteNorad: String?
    var dateRange: Range<Date>

    var satelliteElevationGraphConfigs: SatelliteElevationGraphConfigs = .preset

    static var empty: AppState {
        AppState(
            satellites: .neverLoaded,
            // Default to a dummy address
            // 2000 Broadway, Redwood City, CA 94063
            observerCoordinate: LatLonAlt(lat: 37.486743000691185, lon: -122.22655970246515, alt: 0),
            dateRange: Date().advanced(by: -60 * 60 * 2)..<Date().advanced(by: 60 * 60 * 22)
        )
    }

    var currentSatelliteSnapshots: [SatelliteSnapshot] {
        guard let currentSatelliteNorad = currentSatelliteNorad else {
            return []
        }
        return allSnapshots[currentSatelliteNorad] ?? []
    }
}

enum AppAction {
}

class Store: ReduxStoreBase<AppAction, AppState> {
    static let shared = Store(
        subject: .combine(initialValue: .empty),
        reducer: Reducer<AppAction, AppState>.identity,
        middleware: IdentityMiddleware()
    )
}
