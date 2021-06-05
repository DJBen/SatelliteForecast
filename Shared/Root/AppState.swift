//
//  AppState.swift
//  SatelliteKitTests
//
//  Created by Ben Lu on 6/5/21.
//

import Foundation
import SatelliteKit
import SatelliteForcastCore

struct AppState: Equatable {
    var observerCoordinate: LatLonAlt
    var allSnapshots: [String: [SatelliteSnapshot]] = [:]
    var currentSatelliteNorad: String?
    var dateRange: Range<Date>
    var satelliteElevationGraphConfigs: SatelliteElevationGraphConfigs = .preset

    var tleLoaderState: TLELoaderState = .empty
    var coreLocationState: CoreLocationState = .empty

    static var empty: AppState {
        AppState(
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
