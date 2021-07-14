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
    var julianDateRange: Range<Double>
    var satelliteElevationGraphConfigs: SatelliteElevationGraphConfigs = .preset
    var skyChartState: SkyChartResources = .empty
    var satelliteElevationGraphResources: SatelliteElevationGraphResources = .empty
    /// A mapping from NORAD ID to the satellite state.
    var satellites: [Int: SatelliteTrails] = [:]
    var satelliteSearchText: String = ""
    var satelliteLoaderState: SatelliteLoaderState = .empty
    var coreLocationState: CoreLocationState = .empty
    var observerForPasses: LatLonAlt?

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
