//
//  VSOP87.swift
//  VSOP87
//
//  Created by Ben Lu on 3/17/22.
//  Copyright © 2022 Ben Lu. All rights reserved.
//

public enum PlanetBody {
    case mercury
    case venus
    case earthMoonBarycenter
    case mars
    case jupiter
    case saturn
    case uranus
    case neptune
}

// Heliocentric J2000 Ecliptic Rectangular XYZ.
public struct RectangularCoordinate {
    public let x: Double
    public let y: Double
    public let z: Double

    public init(
        x: Double = 0,
        y: Double = 0,
        z: Double = 0
    ) {
        self.x = x
        self.y = y
        self.z = z
    }

    init(array: [Double]) {
        init(x: array[0], y: array[1], z: array[2])
    }
}

public enum VSOP87 {
    public static func getPlanetBodyCoordinate(_ planetBody: PlanetBody, julianDay: Double) -> RectangularCoordinate {
        let julianCentury = (julianDay - 2451545.0) / 365250.0

        switch planetBody {
        case .mercury:
            return RectangularCoordinate(array: VSOP87a_XSmall.getMercury(t: julianDay))
        case .venus:
            return RectangularCoordinate(array: VSOP87a_XSmall.getVenus(t: julianDay))
        case .earthMoonBarycenter:
            return RectangularCoordinate(array: VSOP87a_XSmall.getEmb(t: julianDay))
        case .mars:
            return RectangularCoordinate(array: VSOP87a_XSmall.getMars(t: julianDay))
        case .jupiter:
            return RectangularCoordinate(array: VSOP87a_XSmall.getJupiter(t: julianDay))
        case .saturn:
            return RectangularCoordinate(array: VSOP87a_XSmall.getSaturn(t: julianDay))
        case .uranus:
            return RectangularCoordinate(array: VSOP87a_XSmall.getUranus(t: julianDay))
        case .neptune:
            return RectangularCoordinate(array: VSOP87a_XSmall.getNeptune(t: julianDay))
        }
    }
}