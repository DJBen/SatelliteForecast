//
//  LocalElementsLoader.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/7/22.
//

import BTree
import Combine
import SatelliteForecast
import SatelliteKit
import SatelliteCatalog

#if DEBUG

/// A testing implementation that loads fixed Elements from local files.
class LocalElementsLoader: ElementsLoader {
    func loadElementsPublisher(category: SatelliteCategory) -> AnyPublisher<Map<UInt, SatelliteInfo>, ElementsLoaderError> {
        Future<Map<UInt, SatelliteInfo>, ElementsLoaderError> { promise in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let elementss = try Elements.loadLocalData(category: category)
                    let info = elementss
                        .map(SatelliteInfo.init(elements:))
                        .reduce(into: Map<UInt, SatelliteInfo>(), { $0[$1.noradIndex] = $1 })
                    promise(.success(info))
                } catch {
                    fatalError("Local file could not be loaded")
                }
            }
        }
        .eraseToAnyPublisher()
    }
}

#endif
