//
//  ElementsLoaderState.swift
//  SatelliteForecastImpl
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
        resources: ElementsLoaderResources = .init(),
        julianDateOffset: Double = 0
    ) {
        self.resources = resources
        self.julianDateOffset = julianDateOffset
    }
}

extension ElementsLoaderState: Equatable {}
