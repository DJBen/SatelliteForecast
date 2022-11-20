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

public struct AppState: Equatable {
    public var navigationState: NavigationState = .init() {
        willSet {
            print("[Navigation] \(navigationState)")
        }
    }

    /// The rendered background sky images, cached for performance.
    public var backgroundSkyResources: BackgroundSkyResources = .init()

    /// The date range from which ephemerides are generated.
    public var skyChartResources: SkyChartResources = .init()

    public var realtimeSkyResources: RealtimeSkyViewResources = .init()

    public var satelliteElevationGraphResources: SatelliteElevationGraphResources = .init()

    public var elementsPropagatorResources: ElementsPropagatorResources = .init()

    /// Location agnostic satellite information, including its orbit and metadata.
    public var elementsLoader: ElementsLoaderResources = .init()

    public var locationResources: LocationResources = .init()

    public var debugMenu: DebugMenuConfig = .init()

    public var notificationResources: NotificationResources = NotificationResources()

    public init() {}
}
