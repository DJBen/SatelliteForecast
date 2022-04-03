//
//  ElementsPropagatorReducer.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/7/21.
//

import Foundation
import os
import SwiftRex
import SatelliteKit
import SatelliteForecast
import BTree

fileprivate let logger = Logger(subsystem: "io.djben.ElementsPropagator", category: "reducer")

extension Reducer where ActionType == ElementsPropagatorAction, StateType == AppState {
    static let elementsPropagatorReducer = Reducer.reduce { action, state in
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
