//
//  TLELoaderMiddleware.swift
//  SatelliteForcast
//
//  Created by Ben Lu on 6/4/21.
//

import Foundation
import Combine
import CombineRex
import SatelliteKit

struct TLELoaderDependencies {
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
                        try TLE(raw: try JSONDecoder().decode(String.self, from: result.data))
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
            case .willLoadTLECategory:
                return .doNothing

            case .loadTLECategories:
                return Effect { context -> AnyPublisher<DispatchedAction<TLELoaderOutputAction>, Never> in
                    let publishers = getState().tles
                        .filter { $1 == .loading }
                        .keys
                        .map(publisher(category:))

                    return Publishers.MergeMany(publishers)
                        .eraseToAnyPublisher()
                }
            }
        }
    }
}
