//
//  VSOP87.swift
//  VSOP87
//
//  Created by Ben Lu on 3/17/22.
//  Copyright © 2022 Ben Lu. All rights reserved.
//

public enum SolarSystemBody {
    case sun
    case mercury
    case venus
    case earth
    case earthMoonBarycenter
    case moon
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
        _ x: Double = 0,
        _ y: Double = 0,
        _ z: Double = 0
    ) {
        self.x = x
        self.y = y
        self.z = z
    }

    public static prefix func - (v: RectangularCoordinate) -> RectangularCoordinate {
        return RectangularCoordinate(-v.x, -v.y, -v.z)
    }

    public static func + (lhs: RectangularCoordinate, rhs: RectangularCoordinate) -> RectangularCoordinate {
        return RectangularCoordinate(lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z)
    }

    public static func - (lhs: RectangularCoordinate, rhs: RectangularCoordinate) -> RectangularCoordinate {
        return RectangularCoordinate(lhs.x - rhs.x, lhs.y - rhs.y, lhs.z - rhs.z)
    }

    public static func * (lhs: RectangularCoordinate, scalar: Double) -> RectangularCoordinate {
        return RectangularCoordinate(lhs.x * scalar, lhs.y * scalar, lhs.z * scalar)
    }

    init(array: [Double]) {
        self.init(array[0], array[1], array[2])
    }
}

public enum VSOP87 {
    public static func getBodyHeliocentricEclipticCoordinate(_ solarSystemBody: SolarSystemBody, julianDay: Double) -> RectangularCoordinate {
        let julianMillenia = (julianDay - 2451545.0) / 365250.0

        switch solarSystemBody {
        case .sun:
            return RectangularCoordinate()
        case .mercury:
            return RectangularCoordinate(array: VSOP87a_XSmall.getMercury(t: julianMillenia))
        case .venus:
            return RectangularCoordinate(array: VSOP87a_XSmall.getVenus(t: julianMillenia))
        case .earth:
            return RectangularCoordinate(array: VSOP87a_XSmall.getEarth(t: julianMillenia))
        case .earthMoonBarycenter:
            return RectangularCoordinate(array: VSOP87a_XSmall.getEmb(t: julianMillenia))
        case .moon:
            return RectangularCoordinate(array: VSOP87a_XSmall.getMoon(earth: VSOP87a_XSmall.getEarth(t: julianMillenia), emb: VSOP87a_XSmall.getEmb(t: julianMillenia)))
        case .mars:
            return RectangularCoordinate(array: VSOP87a_XSmall.getMars(t: julianMillenia))
        case .jupiter:
            return RectangularCoordinate(array: VSOP87a_XSmall.getJupiter(t: julianMillenia))
        case .saturn:
            return RectangularCoordinate(array: VSOP87a_XSmall.getSaturn(t: julianMillenia))
        case .uranus:
            return RectangularCoordinate(array: VSOP87a_XSmall.getUranus(t: julianMillenia))
        case .neptune:
            return RectangularCoordinate(array: VSOP87a_XSmall.getNeptune(t: julianMillenia))
        }
    }
}
