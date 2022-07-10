//
//  SatelliteState.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/8/21.
//

import Foundation
import BTree
import SatelliteKit

/// Everything needed to calculate a satellite's ephemeris and display passes, including the following
/// - An sorted map (B-tree) of existing calculated ephemerides of the satellite. It is coarse and should not be used to render specific
/// passes.
/// - passSnapshots The pass information describing the exact time of rise and set, and sun illumination changes during the pass, and
/// snapshots accompanying each pass.
public struct SatelliteTrails: Equatable {
    public var observer: LatLonAlt
    /// Coarse snapshots
    public var snapshots: [SatelliteSnapshot]
    public var passSnapshots: [PassSnapshots]?

    public init(
        observer: LatLonAlt,
        snapshots: [SatelliteSnapshot] = [],
        passSnapshots: [PassSnapshots]? = nil
    ) {
        self.observer = observer
        self.snapshots = snapshots
        self.passSnapshots = passSnapshots
    }
}
