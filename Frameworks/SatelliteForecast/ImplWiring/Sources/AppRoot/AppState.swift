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
    public var deviceToken: Data?
    public var fcmToken: String?
    
    public var navigationState: NavigationState = .init() {
        willSet {
            print("[Navigation] \(navigationState)")
        }
    }

    /// The rendered background sky images, cached for performance.
    public var backgroundSkyResources: BackgroundSkyResources = .init()

    /// The date range from which ephemerides are generated.
    public var skyChartResources: SkyChartResources = .init()

    /// The calculated realtime satellite propagation result, used in the realtime sky view.
    public var realtimeSkyResources: RealtimeSkyViewResources = .init()

    /// The cached satellite elevation graph.
    public var satelliteElevationGraphResources: SatelliteElevationGraphResources = .init()

    /// The calculated satellite trails (passes, snapshots).
    public var elementsPropagatorResources: ElementsPropagatorResources = .init()

    /// Location agnostic satellite information, including its orbit and metadata.
    public var elementsLoader: ElementsLoaderResources = .init()

    /// The state of current location and reverse geocoding.
    public var locationResources: LocationResources = .init()

    /// The state of debug menu.
    public var debugMenu: DebugMenuConfig = .init()

    /// The state of scheduled notifications.
    public var notificationResources: NotificationResources = NotificationResources()

    /// If turned on, the entire view will be
    public var isNightModeOn: Bool = false

    public init() {}
}
