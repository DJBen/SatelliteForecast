//
//  ElementsLoader.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 4/1/22.
//

import BTree
import Combine

/// Abstracts common logic of satellite loader into publishers.
public protocol ElementsLoader {
    func loadElementsPublisher(category: SatelliteCategory) -> AnyPublisher<Map<UInt, SatelliteInfo>, ElementsLoaderError>
}
