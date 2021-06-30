//
//  MathUtil.swift
//  SatelliteForcastCore
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

/// Quadratic interpolate a list of (x, y) values with a given step n. Will produce n+1 value pairs.
/// - Parameters:
///   - pairs: Pairs of (x, y) values.
///   - steps: Number of interpolation steps.
/// - Returns: n+1 interpolated (x, y) value pairs.
public func quadraticInterpolate(_ pairs: [(Double, Double)], steps: Int) -> [(Double, Double)] {
    if pairs.count < 3 {
        return []
    }
    let a = pairs.map { $0.1 }
    let ori = pairs.map { $0.0 }
    let stepSize = Double(pairs.count - 1) / Double(steps)
    let b: [Double] = Array(stride(from: 0.0, to: Double(pairs.count - 1), by: stepSize))
    let strideB = vDSP_Stride(1)
    var c = [Double](repeating: 0, count: b.count)
    let strideC = vDSP_Stride(1)
    let countC = vDSP_Length(b.count)
    let countA = vDSP_Length(a.count)
    vDSP_vqintD(a, b, strideB, &c, strideC, countC, countA)

    var result: [(Double, Double)] = zip(b, c).enumerated().map { i, x in
        let (bv, cv) = x
        let fl = ori[Int(floor(bv))]
        let ce = ori[Int(ceil(bv))]
        return ((ce - fl) * (bv - floor(bv)) + fl, cv)
    }
    result.append(pairs.last!)
    return result
}
