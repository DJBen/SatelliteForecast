//
//  TLELoaderState.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/4/21.
//

import BTree
import Foundation
import SatelliteForecastCore
import SatelliteKit

public struct TLELoaderResources {
    public var info: [SatelliteCategory: Loadable<Map<Int, SatelliteInfo>, TLELoaderError>]

    public init(
        info: [SatelliteCategory: Loadable<Map<Int, SatelliteInfo>, TLELoaderError>] = [:]
    ) {
        self.info = info
    }

    public subscript(noradIndex: Int) -> SatelliteInfo? {
        return info.values
            .first { $0.content?[noradIndex] != nil }
            .flatMap { $0.content?[noradIndex] }
    }
}

extension TLELoaderResources: Equatable {}

public struct TLELoaderState {
    public var resources: TLELoaderResources
    public var currentDate: Double

    public init(
        resources: TLELoaderResources = .init(),
        currentDate: Double = 0
    ) {
        self.resources = resources
        self.currentDate = currentDate
    }
}

extension TLELoaderState: Equatable {}
