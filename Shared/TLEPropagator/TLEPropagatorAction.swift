//
//  TLEPropagatorAction.swift
//  SatelliteForecastCore
//
//  Created by Ben Lu on 6/6/21.
//

import Foundation
import SatelliteForecastCore
import BTree

enum TLEPropagatorAction {
    /// Called when found the passes for a satellite. Arguments include a list of passes, and the snapshots interlaced with fine snapshots
    /// during the pass.
    case foundPasses([Pass], fineSnapshots: BTree<Double, SatelliteSnapshot>, noradIndex: Int)
    case propagatedSnapshots(BTree<Double, SatelliteSnapshot>, noradIndex: Int)
}
