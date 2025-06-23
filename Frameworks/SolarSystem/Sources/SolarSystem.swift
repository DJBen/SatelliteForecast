//
//  VSOP87.swift
//  VSOP87
//
//  Created by Ben Lu on 3/17/22.
//  Copyright © 2022 Ben Lu. All rights reserved.
//

import Foundation
@preconcurrency import SatelliteKit

extension SolarSystemBody {
    // TODO: implement planet brightness calculation

    public func eci(julianDay: Double) -> Vector {
        VSOP87.getBodyECICoordinate(self, julianDay: julianDay)
    }

    public func aziEle(julianDay: Double, observer: LatLonAlt) -> AziEle {
        azel(
            julianDate: julianDay,
            site: (observer.lat, observer.lon),
            cele: RADec(
                vector: eci(julianDay: julianDay)
            )
        )
    }
}

extension VSOP87 {
    public static func getBodyECICoordinate(
        _ solarSystemBody: SolarSystemBody,
        julianDay: Double
    ) -> Vector {
        let geocentricEclipticalCoordinate = getBodyHeliocentricEclipticCoordinate(solarSystemBody, julianDay: julianDay) - getBodyHeliocentricEclipticCoordinate(.earth, julianDay: julianDay)
        let (x, y, z) = (geocentricEclipticalCoordinate.x, geocentricEclipticalCoordinate.y, geocentricEclipticalCoordinate.z)

        // https://en.wikipedia.org/wiki/Axial_tilt#Earth
        let obliquity: Double = {
            let t = (julianDay - 2451545.0) / (365.25 * 10_000)
            var term = [Double](repeating: 0, count: 11)
            term[0] = 23 + 26 / 60 + 21.448 / 3600.0
            term[1] = -4680.93 / 3600.0 * t
            term[2] = -1.55 / 3600.0 * pow(t, 2)
            term[3] = 1999.25 / 3600.0 * pow(t, 3)
            term[4] = -51.38 / 3600.0 * pow(t, 4)
            term[5] = -249.67 / 3600.0 * pow(t, 5)
            term[6] = -39.05 / 3600.0 * pow(t, 6)
            term[7] = 7.12 / 3600.0 * pow(t, 7)
            term[8] = 27.87 / 3600.0 * pow(t, 8)
            term[9] = 5.79 / 3600.0 * pow(t, 9)
            term[10] = 2.45 / 3600.0 * pow(t, 10)
            return term.reduce(0, +)
        }()

        let sini = sin(obliquity * deg2rad)
        let cosi = cos(obliquity * deg2rad)
        let eci_y = cosi * y - sini * z
        let eci_z = sini * y + cosi * z
        return Vector(x, eci_y, eci_z)
    }
}

extension Vector {
    public init(_ rectangularCoordinate: RectangularCoordinate) {
        self.init(rectangularCoordinate.x, rectangularCoordinate.y, rectangularCoordinate.z)
    }
}
