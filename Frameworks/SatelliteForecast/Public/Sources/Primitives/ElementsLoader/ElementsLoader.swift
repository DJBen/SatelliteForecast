//
//  ElementsLoader.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 4/1/22.
//

import BTree
import Combine

public enum FetchStrategy {
    /// Proritize fetching from online sources, and fallback to local file if network fails.
    case onlineFirst

    /// Use local file if last modified within the specified time interval
    case localWithin(TimeInterval)

    /// If local file exist, always use it.
    case localFirst
}

extension FetchStrategy: Equatable, Hashable, Codable {}

/// Abstracts common logic of satellite loader into publishers.
public protocol ElementsLoader {
    func loadElementsPublisher(
        category: SatelliteCategory,
        fetchStrategy: FetchStrategy
    ) -> AnyPublisher<Map<UInt, SatelliteInfo>, ElementsLoaderError>
}
