//
//  MathUtil.swift
//  SatelliteForecastCore
//
//  Created by Ben Lu on 6/1/21.
//

import Accelerate
import Foundation
import SatelliteKit

/// Converts a ECEF cartesian coordinate (x, y, z) to (ra, dec).
/// - Parameter vector: The cartesian coordiante.
/// - Returns: The (ra, dec).
public func cartesianToRaDec(_ vector: Vector) -> (ra: Double, dec: Double) {
    let (x, y, z) = (vector.x, vector.y, vector.z)
    return (atan2pi(y, x) * rad2deg, asin(z / (x * x + y * y + z * z).squareRoot()) * rad2deg)
}

public let au2Km: Double = 149_598_073
