//
//  TLEPropagatorReducer.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/7/21.
//

import Foundation
import os
import SwiftRex
import SatelliteKit
import SatelliteForecastCore
import BTree

fileprivate let logger = Logger(subsystem: "io.djben.TLEPropagator", category: "reducer")

extension Reducer where ActionType == TLEPropagatorAction, StateType == Store.StateType {
    static let tlePropagatorReducer = Reducer.reduce { action, state in
        switch action {
        case let .foundPasses(passes, snapshots, noradIndex, observer):
            logger.info("Found \(passes.count) passes for \(noradIndex). Detailed snapshots count: \(snapshots.count)")
            if let _ = state.satelliteTrails[noradIndex] {
                state.satelliteTrails[noradIndex]!.snapshots = snapshots
                state.satelliteTrails[noradIndex]!.passes = passes
            } else {
                state.satelliteTrails[noradIndex] = SatelliteTrails(
                    observer: observer,
                    snapshots: snapshots,
                    passes: passes
                )
            }

        case let .propagatedSnapshots(satelliteSnapshots, noradIndex, observer):
            logger.info("Propagated \(satelliteSnapshots.count) snapshots for \(noradIndex).")
            if let _ = state.satelliteTrails[noradIndex] {
                state.satelliteTrails[noradIndex]!.snapshots = satelliteSnapshots
            } else {
                state.satelliteTrails[noradIndex] = SatelliteTrails(
                    observer: observer,
                    snapshots: satelliteSnapshots
                )
            }
        case .purgePassesAndSnapshots:
            state.satelliteTrails = [:]
        }
    }
}
