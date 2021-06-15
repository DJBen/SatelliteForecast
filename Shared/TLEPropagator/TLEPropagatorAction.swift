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
    case foundPasses([PassInformation], fineSnapshots: Map<Date, SatelliteSnapshot>, noradIndex: Int)
    case selectVisiblePass
    case propagatedSnapshots(Map<Date, SatelliteSnapshot>, noradIndex: Int)
}
