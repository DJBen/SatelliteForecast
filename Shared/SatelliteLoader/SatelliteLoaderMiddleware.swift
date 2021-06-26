//
//  SatelliteLoaderMiddleware.swift
//  SatelliteForcast
//
//  Created by Ben Lu on 6/4/21.
//

import Foundation
import os
import Combine
import CombineRex
import SatelliteKit
import SatelliteForcastCore
import SatelliteCatalog

fileprivate let logger = Logger(subsystem: "io.djben.satelliteLoader", category: "middleware")

struct SatelliteLoaderDependencies {
    let updateInterval: TimeInterval = 4 * 60 * 60
}

extension EffectMiddleware where
    InputActionType == SatelliteLoaderInputAction,
    OutputActionType == SatelliteLoaderOutputAction,
    StateType == SatelliteLoaderState,
    Dependencies == SatelliteLoaderDependencies {

    private static func publisher(category: SatelliteCategory) -> AnyPublisher<DispatchedAction<SatelliteLoaderOutputAction>, Never> {
        URLSession.shared
            .dataTaskPublisher(for: URLRequest(url: category.url))
            .mapError { SatelliteLoaderError.other($0) }
            .tryMap { result -> DispatchedAction<SatelliteLoaderOutputAction> in
                precondition(!Thread.isMainThread)
                let tles = try TLE.load(chunk: String(data: result.data, encoding: .utf8)!)
                let info = tles.map { tle -> SatelliteInfo in
                    let satCat = SatCat.with(noradCatID: tle.noradIndex)
                    let ucsSat = UCSSat.with(noradCatID: tle.noradIndex)
                    return SatelliteInfo(
                        noradIndex: tle.noradIndex,
                        satellite: Satellite(withTLE: tle),
                        satCat: satCat,
                        ucsSat: ucsSat
                    )
                }
                // Sort the satellite list in reverse chronological order of the freshness of TLE.
                .sorted(by: { $0.satellite.t₀Days1950 > $1.satellite.t₀Days1950 })
                return DispatchedAction<SatelliteLoaderOutputAction>(
                    .loadedSatelliteInfo(category, info)
                )
            }
            .mapError { error in
                if let satKitError = error as? SatKitError {
                    return .tle(satKitError)
                } else {
                    return .other(error)
                }
            }
            .catch { error in
                Just(
                    DispatchedAction<SatelliteLoaderOutputAction>(
                        .failedLoadingTLEFile(category, error)
                    )
                )
            }
            .eraseToAnyPublisher()
    }

    static var satelliteLoader: MiddlewareReader<SatelliteLoaderDependencies, EffectMiddleware<SatelliteLoaderInputAction, SatelliteLoaderOutputAction, SatelliteLoaderState, SatelliteLoaderDependencies>> {
        EffectMiddleware<SatelliteLoaderInputAction, SatelliteLoaderOutputAction, SatelliteLoaderState, SatelliteLoaderDependencies>
            .onAction { (inputAction, _, getState) -> Effect<SatelliteLoaderDependencies, SatelliteLoaderOutputAction> in
            switch inputAction {
            case let .loadSatelliteCategory(category):
                return Effect(token: category) { context -> AnyPublisher<DispatchedAction<SatelliteLoaderOutputAction>, Never> in
                    if let info = getState().info[category] {
                        let averageTLEAge = info.map {
                            Date(julianDate: getState().referenceDate).timeIntervalSince(Date(daysSince1950: $0.satellite.tle.t₀))
                        }
                        .reduce(0, +) / Double(info.count)

                        if averageTLEAge > context.dependencies.updateInterval {
                            logger.notice("Avg TLE age \(averageTLEAge) too old: updating.")
                            return publisher(category: category)
                        }

                        logger.notice("Avg TLE age \(averageTLEAge) is new: skip update.")
                        return Empty<DispatchedAction<SatelliteLoaderOutputAction>, Never>()
                            .eraseToAnyPublisher()
                    }

                    return publisher(category: category)
                }
            }
        }
    }
}
