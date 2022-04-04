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

    /// A date that mostly approximates the current date.
    var currentDate: Double = Date().julianDate

    /// The rendered background sky images, cached for performance.
    var backgroundSkyResources: BackgroundSkyResources = .init()

    /// The date range from which ephemerides are generated.
    var skyChartResources: SkyChartResources = .init()

    var realtimeSkyResources: RealtimeSkyViewResources = .init()

    var satelliteElevationGraphResources: SatelliteElevationGraphResources = .init()

    var elementsPropagatorResources: ElementsPropagatorResources = .init()

    /// Location agnostic satellite information, including its orbit and metadata.
    var elementsLoader: ElementsLoaderResources = .init()

    var locationState: LocationState = .init()

    var debugMenu: DebugMenuConfig = .init()

    var notificationResources: NotificationResources = NotificationResources()

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
