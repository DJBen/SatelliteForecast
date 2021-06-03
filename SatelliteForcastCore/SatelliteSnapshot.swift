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
    public let date: Date
    public let position: AziEleDst
    public let isIlluminated: Bool

    public init(
        date: Date,
        position: AziEleDst,
        isIlluminated: Bool
    ) {
        self.date = date
        self.position = position
        self.isIlluminated = isIlluminated
    }
}

extension SatelliteSnapshot {
    public enum Interpolation {
        case fixed(TimeInterval)
    }

    public static func populate(
        satellite: Satellite,
        dateRange: Range<Date>,
        observer: LatLonAlt,
        interpolation: Interpolation
    ) -> [SatelliteSnapshot] {
        let strideTo: StrideTo<Double> = {
            switch interpolation {
            case let .fixed(interval):
                return stride(
                    from: dateRange.lowerBound.julianDate,
                    to: dateRange.upperBound.julianDate,
                    by: interval * TimeConstants.sec2day
                )
            }
        }()

        return strideTo.map { (julianDate) -> SatelliteSnapshot in
            return SatelliteSnapshot(satellite: satellite, julianDate: julianDate, observer: observer)
        }
    }

    /// Construct a snapshot of the satellite given a date and observer coordinate.
    /// - Parameters:
    ///   - satellite: The satellite.
    ///   - julianDate: The julian date.
    ///   - observer: The observer coordinate in latitude, longitude and altitude.
    public init(
        satellite: Satellite,
        julianDate: Double,
        observer: LatLonAlt
    ) {
        let eciPosition = satellite.position(julianDays: julianDate)
        let obsCel = geo2eci(julianDays: julianDate, geodetic: observer)

        func topVector2AziEleDst(_ top: Vector) -> AziEleDst {
            let z = top.magnitude()

            return AziEleDst(
                azim: atan2pi(top.y, -top.x) * rad2deg,
                elev: asin(top.z / z) * rad2deg,
                dist: z
            )
        }
        let position = topVector2AziEleDst(cel2top(julianDays: julianDate, satCel: eciPosition, obsCel: obsCel))
        let isIlluminated = AstroAlgorithms.hasLineOfSight(
            object1Geo: eciPosition,
            object2Geo: solarCel(julianDays: julianDate) * au2Km
        )
        self.init(
            date: Date(julianDate: julianDate),
            position: position,
            isIlluminated: isIlluminated
        )
    }

    /// Construct a snapshot of the satellite given a date and observer coordinate.
    /// - Parameters:
    ///   - satellite: The satellite.
    ///   - date: The date.
    ///   - observer: The observer coordinate in latitude, longitude and altitude.
    public init(
        satellite: Satellite,
        date: Date,
        observer: LatLonAlt
    ) {
        self.init(satellite: satellite, julianDate: date.julianDate, observer: observer)
    }
}
