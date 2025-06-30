//
//  LocalElementsLoader.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/7/22.
//

import BTree
import Combine
import Foundation
import SatelliteForecast
@preconcurrency import SatelliteKit
import SatelliteCatalog

#if DEBUG

/// A testing implementation that loads fixed Elements from local files.
class LocalElementsLoader: ElementsLoader {
    let delay: TimeInterval
    let hasConnectivity: Bool

    init(
        delay: TimeInterval = 1,
        hasConnectivity: Bool = true
    ) {
        self.delay = delay
        self.hasConnectivity = hasConnectivity
    }

    func loadElementsPublisher(
        category: SatelliteCategory,
        fetchStrategy: FetchStrategy
    ) -> AnyPublisher<Map<UInt, SatelliteInfo>, ElementsLoaderError> {
        Future<Map<UInt, SatelliteInfo>, ElementsLoaderError> { promise in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let elements = try Elements.loadLocalData(category: category)
                    let info = try elements
                        .map(SatelliteInfo.init(elements:))
                        .reduce(into: Map<UInt, SatelliteInfo>(), { $0[$1.noradIndex] = $1 })
                    promise(.success(info))
                } catch {
                    fatalError("Local file could not be loaded")
                }
            }
        }
        .delay(for: .seconds(delay), scheduler: RunLoop.main)
        .eraseToAnyPublisher()
    }
}

#endif
