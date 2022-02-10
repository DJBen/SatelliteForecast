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

extension Reducer where ActionType == TLEPropagatorAction, StateType == AppState {
    static let tlePropagatorReducer = Reducer.reduce { action, state in
        switch action {
        case let .foundPassesAndSnapshots(passSnapshots, noradIndex, observer):
            logger.info("Found \(passSnapshots.count) passes for \(noradIndex). Detailed snapshots count: \(passSnapshots.count)")
            if let _ = state.satelliteTrails[noradIndex] {
                state.satelliteTrails[noradIndex]!.passSnapshots = passSnapshots
            } else {
                state.satelliteTrails[noradIndex] = SatelliteTrails(
                    observer: observer,
                    passSnapshots: passSnapshots
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
