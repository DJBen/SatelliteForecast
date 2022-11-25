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
    public let fileManager: FileManager
    public let currentDateProvider: () -> Date

    public init(
        session: URLSession,
        fileManager: FileManager,
        currentDateProvider: @escaping () -> Date
    ) {
        self.session = session
        self.fileManager = fileManager
        self.currentDateProvider = currentDateProvider
    }
}

private let fileAccessQueue = DispatchQueue(label: "file_access")

extension ElementsLoaderImpl: ElementsLoader {
    /// Load satellite data of a selected category from local file.
    /// - Parameters:
    ///   - category: The selected category of satellite data to load.
    ///   - freshDuration: The maximum time between now and the
    /// - Returns: A publisher of local satellite data, or any error that occurred while it attempts to read the file.
    private func loadLocalSatelliteDataPublisher(
        category: SatelliteCategory,
        freshDuration: TimeInterval
    ) -> AnyPublisher<Data, Error> {
        Future<Data, Error> { promise in
            fileAccessQueue.async {
                let url = fileManager.temporaryDirectory.appendingPathComponent(
                    category.localFilename,
                    conformingTo: .plainText
                )

                do {
                    let attributes = try fileManager.attributesOfItem(atPath: url.path())

                    if let modificationDate = attributes[.modificationDate] as? Date, currentDateProvider().timeIntervalSince(modificationDate) > freshDuration {
                        promise(.failure(ElementsLoaderError.expired(modificationDate, freshDuration: freshDuration)))
                    } else {
                        do {
                            let data = try Data(contentsOf: url)
                            promise(.success(data))
                        } catch {
                            promise(.failure(ElementsLoaderError.data(error)))
                        }
                    }
                } catch {
                    promise(.failure(ElementsLoaderError.fileManager(error)))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    /// Load satellite data of a selected category from local file. If not exist, it will throw the upstream error provided in the argument.
    /// - Parameters:
    ///   - category: The selected category of satellite data to load.
    ///   - upstreamError: The upstream error. If the local file does not exist, this upstream error will be thrown.
    /// - Returns: A publisher of local satellite data.
    private func loadLocalSatelliteDataFallbackPublisher(category: SatelliteCategory, upstreamError: Error) -> AnyPublisher<Data, Error> {
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

    private func shouldAttemptNetworking(from error: Error) -> Bool {
        if case ElementsLoaderError.expired = error {
            return true
        } else if case ElementsLoaderError.fileManager = error {
            return true
        } else if case ElementsLoaderError.data = error {
            return true
        } else {
            return false
        }
    }

    /// An elements publisher that loads from local source first, if local file exists and the modified date is within the fresh duration.
    /// If an expired local file exists, and the fallback internet connection has failed, it will still use the old ephemerides.
    /// - Parameters:
    ///   - category: The category of satellite.
    ///   - freshDuration: If the difference between the current date and the last modified date of the file is greater than this
    ///   duration, the local file is considered stale and a re-fetch will be attempted. Otherwise the local file will be used.
    /// - Returns: A publisher that loads satellite info.
    private func localFirstElementsPublisher(
        category: SatelliteCategory,
        freshDuration: TimeInterval
    ) -> AnyPublisher<Map<UInt, SatelliteInfo>, ElementsLoaderError> {
        return loadLocalSatelliteDataPublisher(
            category: category,
            freshDuration: freshDuration
        )
        .tryCatch { error in
            if shouldAttemptNetworking(from: error) {
                return session.dataTaskPublisher(
                    for: URLRequest(url: category.url)
                )
                .tryMap { (data, response) in
                    saveLocalSatelliteData(category: category, data: data)

                    return data
                }
                .tryCatch { error in
                    // Try to load local file if exists when network failed.
                    loadLocalSatelliteDataFallbackPublisher(category: category, upstreamError: error)
                }
            } else {
                throw error
            }
        }
        .tryMap { data -> Map<UInt, SatelliteInfo> in
            precondition(!Thread.isMainThread)
            let elements = try Elements.load(chunk: String(data: data, encoding: .utf8)!)
            let info = elements.map(
                SatelliteInfo.init(elements:)
            )
            // Sort the satellite list in reverse chronological order of the freshness of Elements.
                .sorted(by: { $0.elements.t₀ > $1.elements.t₀ })
                .reduce(into: Map<UInt, SatelliteInfo>(), { $0[$1.noradIndex] = $1 })

            return info
        }
        .mapError(ElementsLoaderError.wrapError)
        .eraseToAnyPublisher()
    }

    public func loadElementsPublisher(
        category: SatelliteCategory,
        fetchStrategy: FetchStrategy
    ) -> AnyPublisher<Map<UInt, SatelliteInfo>, ElementsLoaderError> {
        switch fetchStrategy {
        case .onlineFirst:
            return session.dataTaskPublisher(
                for: URLRequest(url: category.url)
            )
            .tryMap { (data, response) in
                saveLocalSatelliteData(category: category, data: data)
                return data
            }
            .tryCatch { error in
                // Try to load local file if exists when network failed.
                loadLocalSatelliteDataFallbackPublisher(category: category, upstreamError: error)
            }
            .tryMap { data -> Map<UInt, SatelliteInfo> in
                precondition(!Thread.isMainThread)
                let elements = try Elements.load(chunk: String(data: data, encoding: .utf8)!)
                let info = elements.map(
                    SatelliteInfo.init(elements:)
                )
                // Sort the satellite list in reverse chronological order of the freshness of Elements.
                .sorted(by: { $0.elements.t₀ > $1.elements.t₀ })
                .reduce(into: Map<UInt, SatelliteInfo>(), { $0[$1.noradIndex] = $1 })

                return info

            }
            .mapError(ElementsLoaderError.wrapError)
            .eraseToAnyPublisher()

        case .localWithin(let duration):
            return localFirstElementsPublisher(
                category: category,
                freshDuration: duration
            )

        case .localFirst:
            return localFirstElementsPublisher(
                category: category,
                freshDuration: .greatestFiniteMagnitude
            )
        }
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
