//
//  LocalTLELoader.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/7/22.
//

import BTree
import Combine
import SatelliteForecastCore
import SatelliteKit
import SatelliteCatalog

/// A testing implementation that loads fixed TLEs from local files.
class LocalTLELoader: TLELoader {
    func loadSatelliteTLEsPublisher(category: SatelliteCategory) -> AnyPublisher<Map<UInt, SatelliteInfo>, TLELoaderError> {
        Future<Map<UInt, SatelliteInfo>, TLELoaderError> { promise in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let filepath = Bundle.main.path(forResource: category.localFilename, ofType: "txt") else {
                    fatalError("No local file available")
                }
                do {
                    let contents = try String(contentsOfFile: filepath)
                    let tles = try TLE.load(chunk: contents)
                    let info = tles
                        .map(SatelliteInfo.init(tle:))
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
