//
//  ElementsLoaderAction.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 6/4/21.
//

import BTree
import Foundation
import SatelliteForecast
@preconcurrency import SatelliteKit

public struct SelectNoradIndexParam {
    public let noradIndex: UInt
    public let dateRange: ClosedRange<Double>
    public let observer: LatLonAlt

    public init(
        noradIndex: UInt,
        dateRange: ClosedRange<Double>,
        observer: LatLonAlt
    ) {
        self.noradIndex = noradIndex
        self.dateRange = dateRange
        self.observer = observer
    }
}

extension SelectNoradIndexParam: Equatable {}

public struct ElementsLoaderCalculatePassParam {
    public let noradIndex: UInt
    public let dateRange: ClosedRange<Double>
    public let observer: LatLonAlt

    public init(
        noradIndex: UInt,
        dateRange: ClosedRange<Double>,
        observer: LatLonAlt
    ) {
        self.noradIndex = noradIndex
        self.dateRange = dateRange
        self.observer = observer
    }
}

extension ElementsLoaderCalculatePassParam: Equatable {}

public enum ElementsLoaderAction {
    /// Load a category of satellite elements
    case loadElements(
        category: SatelliteCategory,
        fetchStrategy: FetchStrategy,
        selectNoradIndex: SelectNoradIndexParam? = nil,
        calculatePass: ElementsLoaderCalculatePassParam? = nil
    )
}

extension ElementsLoaderAction: Equatable {}

public enum ElementsLoaderOutput {
    /// Successfully loaded a cateogy of satellite elements
    case loadedSatelliteElements(
        category: SatelliteCategory,
        satelliteInfo: Map<UInt, SatelliteInfo>,
        selectNoradIndex: SelectNoradIndexParam? = nil,
        calculatePass: ElementsLoaderCalculatePassParam? = nil
    )
    case failedLoadingElements(
        category: SatelliteCategory,
        error: ElementsLoaderError
    )
}

extension ElementsLoaderOutput: Equatable {}
