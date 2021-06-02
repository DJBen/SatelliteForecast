//
//  MathUtil.swift
//  SatelliteForcast
//
//  Created by Ben Lu on 6/1/21.
//

import Foundation
import SatelliteKit

func cartesianToRaDec(_ vector: Vector) -> (ra: Double, dec: Double) {
    let (x, y, z) = (vector.x, vector.y, vector.z)
    return (atan2pi(y, x) * rad2deg, asin(z / (x * x + y * y + z * z).squareRoot()) * rad2deg)
}
