//
//  TLELoaderMiddleware.swift
//  SatelliteForcast
//
//  Created by Ben Lu on 6/4/21.
//

import Foundation
import os
import Combine
import CombineRex
import SatelliteKit

fileprivate let logger = Logger(subsystem: "io.djben.tleLoader", category: "middleware")

struct TLELoaderDependencies {
    let updateInterval: TimeInterval = 4 * 60 * 60
}

extension EffectMiddleware where
    InputActionType == TLELoaderInputAction,
    OutputActionType == TLELoaderOutputAction,
    StateType == TLELoaderState,
    Dependencies == TLELoaderDependencies {

    private static func publisher(category: TLECategory) -> AnyPublisher<DispatchedAction<TLELoaderOutputAction>, Never> {
        URLSession.shared
            .dataTaskPublisher(for: URLRequest(url: category.url))
            .mapError { TLELoaderError.other($0) }
            .tryMap { result -> DispatchedAction<TLELoaderOutputAction> in
                DispatchedAction<TLELoaderOutputAction>(
                    .loadedTLEFile(
                        category,
                        try TLE.load(chunk: String(data: result.data, encoding: .utf8)!)
                    )
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
                    DispatchedAction<TLELoaderOutputAction>(
                        .failedLoadingTLEFile(category, error)
                    )
                )
            }
            .eraseToAnyPublisher()
    }

    static var tleLoader: MiddlewareReader<TLELoaderDependencies, EffectMiddleware<TLELoaderInputAction, TLELoaderOutputAction, TLELoaderState, TLELoaderDependencies>> {
        EffectMiddleware<TLELoaderInputAction, TLELoaderOutputAction, TLELoaderState, TLELoaderDependencies>
            .onAction { (inputAction, _, getState) -> Effect<TLELoaderDependencies, TLELoaderOutputAction> in
            switch inputAction {
            case let .loadTLECategory(category):
                return Effect(token: category) { context -> AnyPublisher<DispatchedAction<TLELoaderOutputAction>, Never> in
                    if let tles = getState().tles[category] {
                        let averageTLEAge = tles.map {  getState().referenceDate.timeIntervalSince(Date(daysSince1950: $0.t₀))
                        }
                        .reduce(0, +) / Double(tles.count)

                        if averageTLEAge > context.dependencies.updateInterval {
                            logger.notice("Avg TLE age \(averageTLEAge) too old: updating.")
                            return publisher(category: category)
                        }

                        logger.notice("Avg TLE age \(averageTLEAge) is new: skip update.")
                        return Empty<DispatchedAction<TLELoaderOutputAction>, Never>()
                            .eraseToAnyPublisher()
                    }

                    return publisher(category: category)
                }
            }
        }
    }
}
