//
//  AppState.swift
//  SatelliteKitTests
//
//  Created by Ben Lu on 6/5/21.
//

import Foundation
import SatelliteKit
import SatelliteForcastCore
import BTree

struct AppState: Equatable {
    /// The date range from which ephemerides are generated.
    var dateRange: Range<Date>
    var satelliteElevationGraphConfigs: SatelliteElevationGraphConfigs = .preset
    var skyChartState: SkyChartRootState = .empty
    var skyChartConfigs: SkyChartConfigs = .preset
    /// A mapping from NORAD ID to the satellite state.
    var satellites: [Int: SatelliteState] = [:]
    var tleLoaderState: TLELoaderState = .empty
    var coreLocationState: CoreLocationState = .empty
    var selectedSatelliteNoradIndex: Int?

    static var empty: AppState {
        AppState(
            dateRange: Date().advanced(by: -60 * 60 * 2)..<Date().advanced(by: 60 * 60 * 22)
        )
    }

    var currentSatelliteSnapshots: Map<Date, SatelliteSnapshot> {
        get {
            guard let selectedSatelliteNoradIndex = selectedSatelliteNoradIndex else {
                return Map()
            }
            return satellites[selectedSatelliteNoradIndex]?.snapshots ?? Map()
        }
        set {
            guard let selectedSatelliteNoradIndex = selectedSatelliteNoradIndex else {
                return
            }
            satellites[selectedSatelliteNoradIndex]?.snapshots = newValue
        }
    }

    var selectedSatelliteTLE: TLE? {
        guard let index = selectedSatelliteNoradIndex else {
            return nil
        }
        return tleLoaderState.tles.values
            .flatMap { $0 }
            .first { $0.noradIndex == index }
    }
}
