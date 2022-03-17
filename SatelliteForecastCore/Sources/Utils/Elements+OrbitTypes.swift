//
//  Elements+OrbitTypes.swift
//  SatelliteForecastCore
//
//  Created by Ben Lu on 3/8/22.
//

import SatelliteKit

public enum OrbitTypeByAltitude {
    /// A low Earth orbit (LEO) is an Earth-centered orbit near the planet, often specified as having a period of 128 minutes or less (making at least 11.25 orbits per day) and an eccentricity less than 0.25.
    case leo
    /// Medium earth orbit
    case meo
    /// Geosynchronous earth orbit
    case geo
    /// High earth orbit
    case heo
}

extension Elements {
    public var orbitTypeByAltitude: OrbitTypeByAltitude {
        let semimajorAxis = (a₀ - 1) * EarthConstants.Rₑ
        let period = M_PI * 2 / n₀
        if period <= 128 && e₀ < 0.25 {
            return .leo
        } else if e₀ < 0.1 && abs(35786 - semimajorAxis) < 1000 {
            return .geo
        } else if semimajorAxis * (1 + e₀) > 35786 {
            return .heo
        } else {
            return .meo
        }
    }
}
