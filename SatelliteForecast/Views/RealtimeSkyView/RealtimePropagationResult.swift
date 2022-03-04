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
    /// The delay before next check.
    /// This is used to reduce redundant satellite propagation by delaying the next check of satellites that are not probable to be visible.
    /// For example a satellite with an elevation of -20 deg cannot rise at least within a few minutes.
    public let nextCheckDelay: Double

    public init(
        noradIndex: Int,
        snapshot: SatelliteSnapshot,
        nextCheckDelay: Double
    ) {
        self.noradIndex = noradIndex
        self.snapshot = snapshot
        self.nextCheckDelay = nextCheckDelay
    }
}

extension RealtimePropagationResult: Equatable {}
