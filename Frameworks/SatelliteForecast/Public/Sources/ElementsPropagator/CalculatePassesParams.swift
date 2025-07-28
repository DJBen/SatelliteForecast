//
//  CalculatePassesParams.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 4/4/22.
//

@preconcurrency import SatelliteKit

public struct CalculatePassesParams: CustomDebugStringConvertible {
    public let selectedNoradIndex: UInt
    public let satelliteInfo: SatelliteInfo
    public let julianDateRange: ClosedRange<Double>
    public let observer: LatLonAlt

    public init(selectedNoradIndex: UInt, satelliteInfo: SatelliteInfo, julianDateRange: ClosedRange<Double>, observer: LatLonAlt) {
        self.selectedNoradIndex = selectedNoradIndex
        self.satelliteInfo = satelliteInfo
        self.julianDateRange = julianDateRange
        self.observer = observer
    }

    public var debugDescription: String {
        return "selectedNoradIndex: \(selectedNoradIndex), julianDateRange: \(julianDateRange), observer: \(observer)"
    }
}

extension CalculatePassesParams: Equatable {}
