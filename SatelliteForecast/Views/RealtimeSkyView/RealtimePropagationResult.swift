//
//  RealtimePropagationResult.swift
//  RealtimeSkyView
//
//  Created by Ben Lu on 3/3/22.
//

import SatelliteForecastCore

public struct RealtimePropagationResult {
    public let noradIndex: Int
    public let snapshot: SatelliteSnapshot
    /// The earliest julian date that we should repropagate a satellite ephemeris again.
    /// This is used to reduce redundant satellite propagation by delaying the next check of satellites that are not probable to be visible.
    /// For example a satellite with an elevation of -20 deg cannot rise at least within a few minutes.
    public let nextCheckJulianDate: Double

    public init(
        noradIndex: Int,
        snapshot: SatelliteSnapshot,
        nextCheckJulianDate: Double
    ) {
        self.noradIndex = noradIndex
        self.snapshot = snapshot
        self.nextCheckJulianDate = nextCheckJulianDate
    }
}

extension RealtimePropagationResult: Equatable {}
