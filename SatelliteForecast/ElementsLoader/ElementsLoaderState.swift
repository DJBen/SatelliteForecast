//
//  ElementsLoaderState.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/4/21.
//

import BTree
import Foundation
import SatelliteForecastCore
import SatelliteKit

public struct ElementsLoaderResources {
    public var info: [SatelliteCategory: Loadable<Map<UInt, SatelliteInfo>, ElementsLoaderError>]
    public var visibleCandidates: Loadable<[SatelliteInfo], ElementsLoaderError>

    public init(
        info: [SatelliteCategory: Loadable<Map<UInt, SatelliteInfo>, ElementsLoaderError>] = [:],
        visibleCandidates: Loadable<[SatelliteInfo], ElementsLoaderError> = .notLoaded
    ) {
        self.info = info
        self.visibleCandidates = visibleCandidates
    }

    public subscript(noradIndex: UInt) -> SatelliteInfo? {
        return info.values
            .first { $0.content?[noradIndex] != nil }
            .flatMap { $0.content?[noradIndex] }
    }
}

extension ElementsLoaderResources: Equatable {}

public struct ElementsLoaderState {
    public var resources: ElementsLoaderResources
    public var currentDate: Double

    public init(
        resources: ElementsLoaderResources = .init(),
        currentDate: Double = 0
    ) {
        self.resources = resources
        self.currentDate = currentDate
    }
}

extension ElementsLoaderState: Equatable {}
