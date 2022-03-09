//
//  RealtimePropagationResult.swift
//  RealtimeSkyView
//
//  Created by Ben Lu on 3/3/22.
//

import SatelliteForecastCore
import SatelliteKit

public struct RealtimePropagationResult {
    public let noradIndex: UInt
    public let snapshot: SatelliteSnapshot
    public let tle: TLE
    /// The earliest julian date that we should repropagate a satellite ephemeris again.
    /// This is used to reduce redundant satellite propagation by delaying the next check of satellites that are not probable to be visible.
    /// For example a satellite with an elevation of -20 deg cannot rise at least within a few minutes.
    public let nextCheckJulianDate: Double

    public init(
        noradIndex: UInt,
        snapshot: SatelliteSnapshot,
        tle: TLE,
        nextCheckJulianDate: Double
    ) {
        self.noradIndex = noradIndex
        self.snapshot = snapshot
        self.tle = tle
        self.nextCheckJulianDate = nextCheckJulianDate
    }
}

extension RealtimePropagationResult: Equatable {}
