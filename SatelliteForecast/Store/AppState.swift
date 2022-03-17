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
    var navigationState: NavigationState = .init() {
        willSet {
            print("[Navigation] \(navigationState)")
        }
    }

    /// A date that mostly approximates the current date.
    var currentDate: Double = Date().julianDate

    /// The rendered background sky images, cached for performance.
    var backgroundSkyResources: BackgroundSkyResources = .init()

    /// The date range from which ephemerides are generated.
    var skyChartResources: SkyChartResources = .init()

    var realtimeSkyResources: RealtimeSkyViewResources = .init()

    var satelliteElevationGraphResources: SatelliteElevationGraphResources = .init()

    /// A mapping from NORAD ID to the satellite state.
    var satelliteTrails: [UInt: SatelliteTrails] = [:]

    /// Location agnostic satellite information, including its orbit and metadata.
    var elementsLoader: ElementsLoaderResources = .init()

    var locationState: LocationState = .init()

    var debugMenu: DebugMenuConfig = .init()

    var notificationState: NotificationState = NotificationState()

    static var empty: AppState {
        return AppState()
    }

    // MARK: - Derived properties

    /// The julian date for consumptions of display and calculation.
    /// This julian date will take into account of artificial offsets in debug mode, and is not always a true representation
    /// of the current date.
    var julianDate: Double {
        currentDate + debugMenu.effectiveOffset
    }

    var selectedSatelliteTrails: SatelliteTrails? {
        navigationState.selectedNoradIndex.flatMap { satelliteTrails[$0] }
    }

    var selectedSatelliteInfo: SatelliteInfo? {
        navigationState.selectedNoradIndex.flatMap { elementsLoader[$0] }
    }

    var currentSatelliteSnapshots: [SatelliteSnapshot] {
        get {
            guard let selectedSatelliteNoradIndex = navigationState.selectedNoradIndex else {
                return []
            }
            return satelliteTrails[selectedSatelliteNoradIndex]?.snapshots ?? []
        }
        set {
            guard let selectedSatelliteNoradIndex = navigationState.selectedNoradIndex else {
                return
            }
            satelliteTrails[selectedSatelliteNoradIndex]?.snapshots = newValue
        }
    }

    var selectedSatellitePass: Pass? {
        guard let noradIndex = navigationState.selectedNoradIndex,
              let selectedPassIndex = navigationState.listNavigation.selectedPassIndex else {
            return nil
        }

        return satelliteTrails[noradIndex]?.passSnapshots?[selectedPassIndex].pass
    }
}
