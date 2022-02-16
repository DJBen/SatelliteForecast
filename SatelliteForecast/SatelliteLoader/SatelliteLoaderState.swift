//
//  SatelliteLoaderState.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/4/21.
//

import BTree
import Foundation
import SatelliteForecastCore
import SatelliteKit

struct SatelliteLoaderResources {
    var info: [SatelliteCategory: Result<Map<Int, SatelliteInfo>, SatelliteLoaderError>] = [:]

    subscript(noradIndex: Int) -> SatelliteInfo? {
        return info.values
            .first { $0.successValue?[noradIndex] != nil }
            .flatMap { $0.successValue?[noradIndex] }
    }
}

extension SatelliteLoaderResources: Equatable {}

struct SatelliteLoaderState: AppStateMappable {
    var resources: SatelliteLoaderResources = .init()
    var currentDate: Double = 0

    static func project(appState: AppState) -> SatelliteLoaderState {
        return SatelliteLoaderState(
            resources: appState.satelliteLoader,
            currentDate: appState.currentDate
        )
    }

    static func apply(appState: inout AppState, state: SatelliteLoaderState) {
        appState.satelliteLoader = state.resources
    }
}

extension SatelliteLoaderState: Equatable {}
