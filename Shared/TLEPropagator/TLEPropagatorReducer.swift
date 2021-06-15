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

        case .selectVisiblePass:
            // Defaults to select the first *visible* pass that satisfies all the following criteria:
            // - Time of pass is after the current time.
            // - Sun elevation is -6° or more below the horizon (having a sky that is dimmer than
            //   civil twilight or dawn).
            // - Transit (maximum elevation) greater than 10 degrees above horizon
            // - Has any illuminated segment during the pass
            switch state.navigationState {
            case let .detail(noradIndex, selectedPassIndex: nil):
                let selectedPassIndex = state.satellites[noradIndex]!.passes.firstIndex(
                    where: {
                        ($0.risesAt ?? $0.setsAt!) > state.tleLoaderState.referenceDate
                            && $0.illumination.hasAnyIllumination
                            && $0.sunElevationAtTransit < -6
                            && $0.transit.elev > 10
                    }
                )
                state.navigationState = .detail(noradIndex: noradIndex, selectedPassIndex: selectedPassIndex)
            default:
                break
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
