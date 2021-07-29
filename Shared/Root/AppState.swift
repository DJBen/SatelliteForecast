//
//  AppState.swift
//  SatelliteKitTests
//
//  Created by Ben Lu on 6/5/21.
//

import Foundation
import SatelliteKit
import SatelliteForecastCore
import BTree

struct AppState: Equatable {
    /// The date range from which ephemerides are generated.
    var skyChartState: SkyChartResources = .empty
    var satelliteElevationGraphResources: SatelliteElevationGraphResources = .empty
    /// A mapping from NORAD ID to the satellite state.
    var satellites: [Int: SatelliteTrails] = [:]
    var satelliteSearchText: String = ""
    var satelliteLoaderState: SatelliteLoaderState = .empty
    var coreLocationState: CoreLocationState = .empty

    var julianDateRange: Range<Double>?
    var observerForPasses: LatLonAlt?
    var debugMenu: DebugMenuConfig = .empty

    /// The julian date for consumptions of display and calculation.
    /// This julian date will take into account of artificial offsets in debug mode, and is not always a true representation
    /// of the current date.
    var julianDate: Double {
        satelliteLoaderState.currentDate + debugMenu.effectiveOffset
    }

    var navigationState: NavigationState = .overview {
        willSet {
            print("[Nav] state changed from \(self.navigationState) to \(newValue)")
        }
    }

    static var empty: AppState {
        AppState(
            julianDateRange: Date().advanced(by: -60 * 60 * 2).julianDate..<Date().advanced(by: 60 * 60 * 46).julianDate
        )
    }

    var selectedSatelliteTrails: SatelliteTrails? {
        navigationState.selectedSatelliteNoradIndex.flatMap { satellites[$0] }
    }

    var selectedSatelliteInfo: SatelliteInfo? {
        navigationState.selectedSatelliteNoradIndex.flatMap { satelliteLoaderState[$0] }
    }

    var currentSatelliteSnapshots: BTree<Double, SatelliteSnapshot> {
        get {
            guard let selectedSatelliteNoradIndex = navigationState.selectedSatelliteNoradIndex else {
                return BTree()
            }
            return satellites[selectedSatelliteNoradIndex]?.snapshots ?? BTree()
        }
        set {
            guard let selectedSatelliteNoradIndex = navigationState.selectedSatelliteNoradIndex else {
                return
            }
            satellites[selectedSatelliteNoradIndex]?.snapshots = newValue
        }
    }

    var selectedSatellitePassIndex: Int? {
        switch navigationState {
        case let .pass(_, _, selectedPassIndex):
            return selectedPassIndex
        default:
            return nil
        }
    }

    var selectedSatellitePass: Pass? {
        switch navigationState {
        case let .pass(_, noradIndex, selectedPassIndex):
            return satellites[noradIndex]?.passes?[selectedPassIndex]
        default:
            return nil
        }
    }
}
