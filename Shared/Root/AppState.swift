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
    var skyChartState: SkyChartRootState = .empty
    /// A mapping from NORAD ID to the satellite state.
    var satellites: [Int: SatelliteState] = [:]
    var tleLoaderState: TLELoaderState = .empty
    var coreLocationState: CoreLocationState = .empty

    // Navigation
    enum NavigationState: Equatable {
        case list
        case allPasses(noradIndex: Int)
        case pass(noradIndex: Int, selectedPassIndex: Int)
    }
    var navigationState: NavigationState = .list

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

    var selectedSatelliteState: SatelliteState? {
        selectedSatelliteNoradIndex.flatMap { satellites[$0] }
    }

    static var empty: AppState {
        AppState(
            julianDateRange: Date().advanced(by: -60 * 60 * 2).julianDate..<Date().advanced(by: 60 * 60 * 46).julianDate
        )
    }

    var currentSatelliteSnapshots: Map<Double, SatelliteSnapshot> {
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

    var selectedSatellitePassIndex: Int? {
        switch navigationState {
        case let .pass(_, selectedPassIndex):
            return selectedPassIndex
        default:
            return nil
        }
    }

    var selectedSatellitePass: PassInformation? {
        switch navigationState {
        case let .pass(noradIndex, selectedPassIndex):
            return satellites[noradIndex]?.passes[selectedPassIndex]
        default:
            return nil
        }
    }
}
