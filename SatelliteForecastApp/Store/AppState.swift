//
//  AppState.swift
//  SatelliteKitTests
//
//  Created by Ben Lu on 6/5/21.
//

import Foundation
import SatelliteKit
import SatelliteForecast
import BTree

struct AppState: Equatable {
    var navigationState: NavigationState = .init() {
        willSet {
            print("[Navigation] \(navigationState)")
        }
    }

    /// The rendered background sky images, cached for performance.
    var backgroundSkyResources: BackgroundSkyResources = .init()

    /// The date range from which ephemerides are generated.
    var skyChartResources: SkyChartResources = .init()

    var realtimeSkyResources: RealtimeSkyViewResources = .init()

    var satelliteElevationGraphResources: SatelliteElevationGraphResources = .init()

    var elementsPropagatorResources: ElementsPropagatorResources = .init()

    /// Location agnostic satellite information, including its orbit and metadata.
    var elementsLoader: ElementsLoaderResources = .init()

    var locationResources: LocationResources = .init()

    var debugMenu: DebugMenuConfig = .init()

    var notificationResources: NotificationResources = NotificationResources()

    static var empty: AppState {
        return AppState()
    }

    // MARK: - Derived properties

    var selectedSatelliteInfo: SatelliteInfo? {
        navigationState.selectedNoradIndex.flatMap { elementsLoader[$0] }
    }

    var selectedSatellitePass: Pass? {
        guard let noradIndex = navigationState.selectedNoradIndex,
              let selectedPassIndex = navigationState.listNavigation.selectedPassIndex else {
            return nil
        }

        return elementsPropagatorResources.satelliteTrails[noradIndex]?.passSnapshots?[selectedPassIndex].pass
    }
}
