//
//  SatelliteState.swift
//  SatelliteForecastCore
//
//  Created by Ben Lu on 6/8/21.
//

import Foundation
import BTree
import SatelliteKit

/// Everything needed to calculate a satellite's ephemeris and display passes, including the following
/// - An ordered map (B-tree) of existing calculated ephemerides of the satellite. It will grow as more calculations are performed.
/// It may unevenly contain ephemerides that are only a few seconds apart for the passes over observer's location, and contain coarse
/// ones that are approximately minutes apart for the rest of their orbits.
/// - Passes The pass information describing the exact time of rise and set, and sun illumination changes during the pass.
public struct SatelliteTrails: Equatable {
    public var observer: LatLonAlt
    public var snapshots: BTree<Double, SatelliteSnapshot>
    public var passes: [Pass]?

    public init(
        observer: LatLonAlt,
        snapshots: BTree<Double, SatelliteSnapshot> = BTree(),
        passes: [Pass]? = nil
    ) {
        self.observer = observer
        self.snapshots = snapshots
        self.passes = passes
    }
}
