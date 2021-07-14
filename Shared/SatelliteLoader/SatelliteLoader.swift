//
//  SatelliteLoader.swift
//  SatelliteForcast (iOS)
//
//  Created by Ben Lu on 7/9/21.
//

import BTree
import Combine
import SatelliteCatalog
import SatelliteForcastCore
import SatelliteKit

/// Abstracts common logic of satellite loader into publishers.
enum SatelliteLoader {
    static func loadSatelliteCategoryPublisher(category: SatelliteCategory) -> AnyPublisher<SatelliteLoaderOutputAction, Never> {
        URLSession.shared
            .dataTaskPublisher(for: URLRequest(url: category.url))
            .mapError { SatelliteLoaderError.other($0) }
            .tryMap { result -> SatelliteLoaderOutputAction in
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
                .reduce(into: Map<Int, SatelliteInfo>(), { $0[$1.noradIndex] = $1 })

                return .loadedSatelliteInfo(category, info)

            }
            .mapError { error in
                if let satKitError = error as? SatKitError {
                    return .tle(satKitError)
                } else {
                    return .other(error)
                }
            }
            .catch { error in
                Just(.failedLoadingTLEFile(category, error))
            }
            .eraseToAnyPublisher()
    }
}
