//
//  Elements+GroundTrack.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 4/3/22.
//

@preconcurrency import SatelliteKit
import CoreLocation
import SatelliteForecast

extension Elements {
    public func generateGroundTrack(
        julianDateRange: ClosedRange<Double>,
        interval: TimeInterval,
    ) throws -> [DateCoordinate] {
        let satellite = Satellite(withTLE: self)
        return try stride(
            from: julianDateRange.lowerBound,
            to: julianDateRange.upperBound,
            by: interval
        ).map { julianDate -> DateCoordinate in
             return DateCoordinate(
                julianDate: julianDate,
                coordinate: try satellite.geoPosition(julianDays: julianDate),
             )
        }
    }
}
