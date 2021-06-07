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
    var allSnapshots: [Int: [SatelliteSnapshot]] = [:]
    /// The date range from which ephemerides are generated.
    var dateRange: Range<Date>
    var satelliteElevationGraphConfigs: SatelliteElevationGraphConfigs = .preset
    var skyChartConfigs: SkyChartConfigs = .preset
    var skyChartState: SkyChartRootState = SkyChartRootState(
        skyReferenceDate: Date()
    )

    var tleLoaderState: TLELoaderState = .empty
    var coreLocationState: CoreLocationState = .empty
    var selectedSatelliteNoradIndex: Int?

    static var empty: AppState {
        AppState(
            dateRange: Date().advanced(by: -60 * 60 * 2)..<Date().advanced(by: 60 * 60 * 22)
        )
    }

    var currentSatelliteSnapshots: [SatelliteSnapshot] {
        get {
            guard let selectedSatelliteNoradIndex = selectedSatelliteNoradIndex else {
                return []
            }
            return allSnapshots[selectedSatelliteNoradIndex] ?? []
        }
        set {
            guard let selectedSatelliteNoradIndex = selectedSatelliteNoradIndex else {
                return
            }
            allSnapshots[selectedSatelliteNoradIndex] = newValue
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
