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
    var satelliteLoaderState: SatelliteLoaderState = .empty
    var coreLocationState: CoreLocationState = .empty
    var observerForPasses: LatLonAlt?

    // Navigation
    enum NavigationState: Equatable {
        case list
        case allPasses(noradIndex: Int)
        case pass(noradIndex: Int, selectedPassIndex: Int)
    }
    var navigationState: NavigationState = .list {
        willSet {
            print("[Nav] state changed from \(self.navigationState) to \(newValue)")
        }
    }

    // MARK: Derived Properties
    var selectedSatelliteNoradIndex: Int? {
        get {
            switch navigationState {
            case let .allPasses(noradIndex), let .pass(noradIndex, _):
                return noradIndex
            case .list:
                return nil
            }
        }

        set {
            if let newValue = newValue {
                switch navigationState {
                case .list, .allPasses(noradIndex: _):
                    self.navigationState = .allPasses(noradIndex: newValue)
                case let .pass(noradIndex, selectedPassIndex):
                    if newValue == noradIndex {
                        return
                    }
                    self.navigationState = .pass(noradIndex: newValue, selectedPassIndex: selectedPassIndex)
                }
            } else {
                self.navigationState = .list
            }
        }
    }

    var selectedSatelliteState: SatelliteTrails? {
        selectedSatelliteNoradIndex.flatMap { satellites[$0] }
    }

    static var empty: AppState {
        AppState(
            julianDateRange: Date().advanced(by: -60 * 60 * 2).julianDate..<Date().advanced(by: 60 * 60 * 46).julianDate
        )
    }

    var currentSatelliteSnapshots: BTree<Double, SatelliteSnapshot> {
        get {
            guard let selectedSatelliteNoradIndex = selectedSatelliteNoradIndex else {
                return BTree()
            }
            return satellites[selectedSatelliteNoradIndex]?.snapshots ?? BTree()
        }
        set {
            guard let selectedSatelliteNoradIndex = selectedSatelliteNoradIndex else {
                return
            }
            satellites[selectedSatelliteNoradIndex]?.snapshots = newValue
        }
    }

    var selectedSatelliteInfo: SatelliteInfo? {
        guard let index = selectedSatelliteNoradIndex else {
            return nil
        }
        return satelliteLoaderState.info.values
            .flatMap { $0 }
            .first { $0.noradIndex == index }
    }

    var selectedSatellitePassIndex: Int? {
        switch navigationState {
        case let .pass(_, selectedPassIndex):
            return selectedPassIndex
        default:
            return nil
        }
    }

    var selectedSatellitePass: Pass? {
        switch navigationState {
        case let .pass(noradIndex, selectedPassIndex):
            return satellites[noradIndex]?.passes?[selectedPassIndex]
        default:
            return nil
        }
    }
}
