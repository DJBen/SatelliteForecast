//
//  ElementsPropagatorAction.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 6/6/21.
//

import Foundation
import SatelliteForecast
import SatelliteKit
import BTree

public enum ElementsPropagatorAction {
    /// Clear all passes and snapshots
    case purgePassesAndSnapshots
    /// Calculate the passes of a satellite over a time periods.
    case calculatePasses(CalculatePassesParams)
    /// Recalculate the passes of a satellite over a time periods by clearing the existing results first.
    case recalculatePasses(CalculatePassesParams)
}

extension ElementsPropagatorAction: Equatable {}

public enum ElementsPropagatorOutput {
    /// Called when found the passes for a satellite. Arguments include a list of passes, and the snapshots interlaced with fine snapshots
    /// during the pass.
    case foundPassesAndSnapshots([PassSnapshots], noradIndex: UInt, observer: LatLonAlt)
    /// Generated coarse snapshots of ephemerides of a satellite, relative to an observer.
    case propagatedSnapshots([SatelliteSnapshot], noradIndex: UInt, observer: LatLonAlt)
}

extension ElementsPropagatorOutput: Equatable {}
