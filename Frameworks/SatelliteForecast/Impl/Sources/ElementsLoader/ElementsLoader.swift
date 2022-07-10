//
//  ElementsLoader.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 7/9/21.
//

import BTree
import Combine
import QSMag
import SatelliteCatalog
import SatelliteCatalogImpl_SQLite
import SatelliteForecast
import SatelliteKit

public struct ElementsLoaderImpl {
    public let session: URLSession

    public init(session: URLSession) {
        self.session = session
    }
}

extension ElementsLoaderImpl: ElementsLoader {
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

    public func loadElementsPublisher(category: SatelliteCategory) -> AnyPublisher<Map<UInt, SatelliteInfo>, ElementsLoaderError> {
        session
            .dataTaskPublisher(for: URLRequest(url: category.url))
            .tryMap { (data, response) in
                return data
            }
            .tryCatch { error in
                // Try to load local file if exists when network failed.
                loadLocalSatelliteDataPublisher(category: category, upstreamError: error)
            }
            .mapError { ElementsLoaderError.other($0) }
            .tryMap { data -> Map<UInt, SatelliteInfo> in
                precondition(!Thread.isMainThread)
                let elementss = try Elements.load(chunk: String(data: data, encoding: .utf8)!)
                let info = elementss
                    .map(SatelliteInfo.init(elements:))
                    // Sort the satellite list in reverse chronological order of the freshness of Elements.
                    .sorted(by: { $0.elements.t₀ > $1.elements.t₀ })
                    .reduce(into: Map<UInt, SatelliteInfo>(), { $0[$1.noradIndex] = $1 })

                saveLocalSatelliteData(category: category, data: data)
                
                return info

            }
            .mapError { error in
                if let satKitError = error as? SatKitError {
                    return .elements(satKitError)
                } else {
                    return .other(error)
                }
            }
            .eraseToAnyPublisher()
    }
}

extension SatelliteInfo {
    public init(elements: Elements) {
        let satCat = SatCat.with(noradCatID: Int(elements.noradIndex))
        let ucsSat = UCSSat.with(noradCatID: Int(elements.noradIndex))
        let qsMag = QSMag.with(noradIndex: elements.noradIndex)
        self.init(
            elements: elements,
            satCat: satCat,
            ucsSat: ucsSat,
            qsMag: qsMag
        )
    }
}
