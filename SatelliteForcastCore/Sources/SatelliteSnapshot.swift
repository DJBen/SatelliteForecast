//
//  SatelliteSnapshot.swift
//  SatelliteForcastCore
//
//  Created by Ben Lu on 6/2/21.
//

import Foundation
import SatelliteKit

/// A snapshot of the satellite of a specific date, coordinate, velocity and whether
/// if it is illuminated by sunlight.
public struct SatelliteSnapshot {
    public let julianDate: Double
    public let position: AziEleDst
    public let isIlluminated: Bool

    /// The sun's elevation, ranging from -90 to 90 degrees.
    public let sunElevation: Double

    public init(
        julianDate: Double,
        position: AziEleDst,
        isIlluminated: Bool,
        sunElevation: Double
    ) {
        self.julianDate = julianDate
        self.position = position
        self.isIlluminated = isIlluminated
        self.sunElevation = sunElevation
    }
}

extension SatelliteSnapshot: Equatable {}

extension SatelliteSnapshot: Hashable {}
