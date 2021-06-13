//
//  TLEPropagatorReducer.swift
//  SatelliteForcast (iOS)
//
//  Created by Ben Lu on 6/7/21.
//

import Foundation
import os
import SwiftRex
import SatelliteForcastCore
import BTree

fileprivate let logger = Logger(subsystem: "io.djben.TLEPropagator", category: "reducer")

extension Reducer where ActionType == TLEPropagatorAction, StateType == Store.StateType {
    static let tlePropagatorReducer = Reducer.reduce { action, state in
        switch action {
        case let .foundPasses(passes, snapshots, noradIndex):
            logger.info("Found \(passes.count) passes for \(noradIndex). Detailed snapshots count: \(snapshots.count)")
            if let _ = state.satellites[noradIndex] {
                state.satellites[noradIndex]!.snapshots = snapshots
                state.satellites[noradIndex]!.passes = passes
            } else {
                state.satellites[noradIndex] = SatelliteState(snapshots: snapshots, passes: passes)
            }
        case let .propagatedSnapshots(satelliteSnapshots, noradIndex):
            logger.info("Propagated \(satelliteSnapshots.count) snapshots for \(noradIndex).")
            if let _ = state.satellites[noradIndex] {
                state.satellites[noradIndex]!.snapshots = satelliteSnapshots
            } else {
                state.satellites[noradIndex] = SatelliteState(snapshots: satelliteSnapshots, passes: [])
            }
        }
    }
}
