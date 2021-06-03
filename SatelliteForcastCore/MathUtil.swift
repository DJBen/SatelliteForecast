//
//  MathUtil.swift
//  SatelliteForcastCore
//
//  Created by Ben Lu on 6/1/21.
//

import Foundation
import SatelliteKit

public func cartesianToRaDec(_ vector: Vector) -> (ra: Double, dec: Double) {
    let (x, y, z) = (vector.x, vector.y, vector.z)
    return (atan2pi(y, x) * rad2deg, asin(z / (x * x + y * y + z * z).squareRoot()) * rad2deg)
}

public let au2Km: Double = 149_598_073

extension Vector {
    public func magnitudeSquared() -> Double {
        return self.x*self.x + self.y*self.y + self.z*self.z
    }

    public static func * (lhs: Vector, scalar: Double) -> Vector {
        return Vector(lhs.x * scalar, lhs.y * scalar, lhs.z * scalar)
    }
}
