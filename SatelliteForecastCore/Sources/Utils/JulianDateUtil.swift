//
//  JulianDateUtil.swift
//  JulianDateUtil
//
//  Created by Ben Lu on 7/29/21.
//

import Foundation
import SwiftDate
import SatelliteKit

public enum JulianDateUtil {
    public static func createJulianDateRange(
        now: Double,
        before: Double = 2 * TimeConstants.hrs2day,
        after: Double = 7 * 24 * TimeConstants.hrs2day,
        roundingTo roundDateMode: RoundDateMode = .to10Mins
    ) -> ClosedRange<Double> {
        ((now - before)...(now + after)).roundJulianDate(roundDateMode)
    }
}

extension ClosedRange where Bound == Double {
    public func roundJulianDate(_ roundDateMode: RoundDateMode) -> ClosedRange<Bound> {
        Date(julianDate: lowerBound).dateRoundedAt(at: roundDateMode).julianDate...Date(julianDate: upperBound).dateRoundedAt(at: roundDateMode).julianDate
    }

    public func roughlyEqualTo(_ rhs: ClosedRange, tolerance: Double) -> Bool {
        Self.withinTolerance(lhs: self, rhs: rhs, tolerance: tolerance)
    }

    public static func withinTolerance(lhs: ClosedRange, rhs: ClosedRange, tolerance: Double) -> Bool {
        return abs(lhs.lowerBound - rhs.lowerBound) < tolerance && abs(lhs.lowerBound - rhs.lowerBound) < tolerance
    }

    public static func ~=(lhs: ClosedRange, rhs: ClosedRange) -> Bool {
        return withinTolerance(lhs: lhs, rhs: rhs, tolerance: 1e-8)
    }
}

extension Double {
    public func roundJulianDate(_ roundDateMode: RoundDateMode) -> Double {
        Date(julianDate: self).dateRoundedAt(at: roundDateMode).julianDate
    }
}
