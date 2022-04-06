//
//  ElementsLoaderState.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/4/21.
//

import BTree
import Foundation
import SatelliteForecast
import SatelliteKit

public struct ElementsLoaderState {
    public var resources: ElementsLoaderResources
    public var julianDateOffset: Double

    public init(
        resources: ElementsLoaderResources,
        julianDateOffset: Double
    ) {
        self.resources = resources
        self.julianDateOffset = julianDateOffset
    }
}

extension ElementsLoaderState: Equatable {}
