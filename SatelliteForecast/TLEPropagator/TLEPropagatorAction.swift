//
//  TLEPropagatorAction.swift
//  SatelliteForecastCore
//
//  Created by Ben Lu on 6/6/21.
//

import Foundation
import SatelliteForecastCore
import SatelliteKit
import BTree

enum TLEPropagatorAction {
    /// Called when found the passes for a satellite. Arguments include a list of passes, and the snapshots interlaced with fine snapshots
    /// during the pass.
    case foundPassesAndSnapshots([PassSnapshots], noradIndex: Int, observer: LatLonAlt)
    /// Generated coarse snapshots of ephemerides of a satellite, relative to an observer.
    case propagatedSnapshots(BTree<Double, SatelliteSnapshot>, noradIndex: Int, observer: LatLonAlt)
    case purgePassesAndSnapshots
}
