//
//  SatelliteLoader.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 7/9/21.
//

import BTree
import Combine
import SatelliteCatalog
import SatelliteCatalogImpl_SQLite
import SatelliteForecastCore
import SatelliteKit

/// Abstracts common logic of satellite loader into publishers.
protocol SatelliteLoader {
    func loadSatelliteCategoryPublisher(category: SatelliteCategory) -> AnyPublisher<Map<Int, SatelliteInfo>, SatelliteLoaderError>
}

struct SatelliteLoaderImpl {
    let session: URLSession
}

extension SatelliteLoaderImpl: SatelliteLoader {
    /// Load satellite data of a selected category from local file. If not exist, it will throw the upstream error provided in the argument.
    /// - Parameters:
    ///   - category: The selected category of satellite data to load.
    ///   - upstreamError: The upstream error. If the local file does not exist, this upstream error will be thrown.
    /// - Returns: A publisher of local satellite data.
    private func loadLocalSatelliteDataPublisher(category: SatelliteCategory, upstreamError: Error) -> AnyPublisher<Data, Error> {
        Future<Data, Error> { promise in
            let url = URL(fileURLWithPath: category.localFilename, relativeTo: FileManager.default.temporaryDirectory)
                .appendingPathExtension("txt")
            do {
                let data = try Data(contentsOf: url)
                promise(.success(data))
            } catch {
                promise(.failure(upstreamError))
            }
        }
        .eraseToAnyPublisher()
    }

    private func saveLocalSatelliteData(category: SatelliteCategory, data: Data) {
        let url = URL(fileURLWithPath: category.localFilename, relativeTo: FileManager.default.temporaryDirectory)
            .appendingPathExtension("txt")
        do {
            try data.write(to: url)
        } catch {
            print("Error saving satellite data for \(category) to \(url): \(error)")
        }
    }

    func loadSatelliteCategoryPublisher(category: SatelliteCategory) -> AnyPublisher<Map<Int, SatelliteInfo>, SatelliteLoaderError> {
        session
            .dataTaskPublisher(for: URLRequest(url: category.url))
            .map { $0.data }
            .tryCatch { error in
                // Try to load local file if exists when network failed.
                loadLocalSatelliteDataPublisher(category: category, upstreamError: error)
            }
            .mapError { SatelliteLoaderError.other($0) }
            .tryMap { data -> Map<Int, SatelliteInfo> in
                precondition(!Thread.isMainThread)
                let tles = try TLE.load(chunk: String(data: data, encoding: .utf8)!)
                let info = tles
                    .map(SatelliteInfo.init(tle:))
                    // Sort the satellite list in reverse chronological order of the freshness of TLE.
                    .sorted(by: { $0.tle.t₀ > $1.tle.t₀ })
                    .reduce(into: Map<Int, SatelliteInfo>(), { $0[$1.noradIndex] = $1 })

                saveLocalSatelliteData(category: category, data: data)
                
                return info

            }
            .mapError { error in
                if let satKitError = error as? SatKitError {
                    return .tle(satKitError)
                } else {
                    return .other(error)
                }
            }
            .eraseToAnyPublisher()
    }
}

fileprivate extension SatelliteInfo {
    init(tle: TLE) {
        let satCat = SatCat.with(noradCatID: tle.noradIndex)
        let ucsSat = UCSSat.with(noradCatID: tle.noradIndex)
        self.init(
            noradIndex: tle.noradIndex,
            tle: tle,
            satCat: satCat,
            ucsSat: ucsSat
        )
    }
}
