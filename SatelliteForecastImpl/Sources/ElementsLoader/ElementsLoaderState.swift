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
