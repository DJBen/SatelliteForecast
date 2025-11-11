//
//  ElementsLoaderState.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 6/4/21.
//

import BTree
import Foundation
import SatelliteForecast
@preconcurrency import SatelliteKit

public struct ElementsLoaderState {
    public var resources: ElementsLoaderResources
    public var julianDateOffset: Double
    public var simulateTLEFailure: Bool

    public init(
        resources: ElementsLoaderResources = .init(),
        julianDateOffset: Double = 0,
        simulateTLEFailure: Bool = false
    ) {
        self.resources = resources
        self.julianDateOffset = julianDateOffset
        self.simulateTLEFailure = simulateTLEFailure
    }
}

extension ElementsLoaderState: Equatable {}
