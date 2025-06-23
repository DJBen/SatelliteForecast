//
//  JulianDateUtil.swift
//  JulianDateUtil
//
//  Created by Ben Lu on 7/29/21.
//

import Foundation
@preconcurrency import SatelliteKit

public enum JulianDateUtil {
    public static func createJulianDateRange(
        now: Double,
        before: Double = 2 * TimeConstants.hrs2day,
        after: Double = 7 * 24 * TimeConstants.hrs2day,
        roundingTo roundDateMode: RoundDateMode = .toMins(10)
    ) -> ClosedRange<Double> {
        ((now - before)...(now + after)).roundJulianDate(roundDateMode)
    }
}

public struct RoundDateMode {
    let mins: Int

    public static func toMins(_ mins: Int) -> RoundDateMode {
        RoundDateMode(mins: mins)
    }
}

extension ClosedRange where Bound == Double {
    public func roundJulianDate(_ roundDateMode: RoundDateMode) -> ClosedRange<Bound> {
        lowerBound.roundJulianDate(roundDateMode)...upperBound.roundJulianDate(roundDateMode)
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
        Date(julianDate: self).rounded(
            minutes: TimeInterval(roundDateMode.mins)
        ).julianDate
    }
}

enum DateRoundingType {
    case round
    case ceil
    case floor
}

extension Date {
    func rounded(minutes: TimeInterval, rounding: DateRoundingType = .round) -> Date {
        return rounded(seconds: minutes * 60, rounding: rounding)
    }
    func rounded(seconds: TimeInterval, rounding: DateRoundingType = .round) -> Date {
        var roundedInterval: TimeInterval = 0
        switch rounding  {
        case .round:
            roundedInterval = (timeIntervalSinceReferenceDate / seconds).rounded() * seconds
        case .ceil:
            roundedInterval = ceil(timeIntervalSinceReferenceDate / seconds) * seconds
        case .floor:
            roundedInterval = floor(timeIntervalSinceReferenceDate / seconds) * seconds
        }
        return Date(timeIntervalSinceReferenceDate: roundedInterval)
    }
}
