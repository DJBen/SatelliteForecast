//
//  TLEPropagatorAction.swift
//  SatelliteForcastCore
//
//  Created by Ben Lu on 6/6/21.
//

import Foundation
import SatelliteForcastCore

enum TLEPropagatorAction {
    case foundPasses([PassInformation], searchDateRange: Range<Date>, noradIndex: Int)
    case propagatedSnapshots([SatelliteSnapshot], noradIndex: Int)
}
