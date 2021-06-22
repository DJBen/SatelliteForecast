//
//  TLEPropagatorAction.swift
//  SatelliteForcastCore
//
//  Created by Ben Lu on 6/6/21.
//

import Foundation
import SatelliteForcastCore
import BTree

enum TLEPropagatorAction {
    case foundPasses([Pass], fineSnapshots: BTree<Double, SatelliteSnapshot>, noradIndex: Int)
    case selectVisiblePass
    case propagatedSnapshots(BTree<Double, SatelliteSnapshot>, noradIndex: Int)
}
