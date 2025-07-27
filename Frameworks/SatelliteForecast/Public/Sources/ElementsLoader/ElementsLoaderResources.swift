//
//  ElementsLoaderResources.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/4/21.
//

import BTree
import Foundation
@preconcurrency import SatelliteKit

public struct ElementsLoaderResources {
    public var info: [SatelliteCategory: Loadable<Map<UInt, SatelliteInfo>, ElementsLoaderError>]
    public var filteredSatellites: Map<UInt, SatelliteInfo>?
    public var visibleCandidates: Loadable<[SatelliteInfo], ElementsLoaderError>

    public init(
        info: [SatelliteCategory: Loadable<Map<UInt, SatelliteInfo>, ElementsLoaderError>] = [:],
        filteredSatellites: Map<UInt, SatelliteInfo>? = nil,
        visibleCandidates: Loadable<[SatelliteInfo], ElementsLoaderError> = .notLoaded
    ) {
        self.info = info
        self.filteredSatellites = filteredSatellites
        self.visibleCandidates = visibleCandidates
    }

    public subscript(noradIndex: UInt) -> SatelliteInfo? {
        return info.values
            .first { $0.content?[noradIndex] != nil }
            .flatMap { $0.content?[noradIndex] }
    }
}

extension ElementsLoaderResources: Equatable {}
