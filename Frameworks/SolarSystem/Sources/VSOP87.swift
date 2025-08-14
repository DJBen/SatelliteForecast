//
//  VSOP87.swift
//  VSOP87
//
//  Created by Ben Lu on 3/17/22.
//  Copyright © 2022 Ben Lu. All rights reserved.
//

public enum SolarSystemBody: Equatable, CaseIterable, Hashable, Codable {
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

public enum VSOP87 {
    public static func getBodyHeliocentricEclipticCoordinate(
        _ solarSystemBody: SolarSystemBody, 
        julianDay: Double
    ) -> SIMD3<Double> {
        let julianMillenia = (julianDay - 2451545.0) / 365250.0

        switch solarSystemBody {
        case .sun:
            return .zero
        case .mercury:
            return VSOP87a_XSmall.getMercury(t: julianMillenia)
        case .venus:
            return VSOP87a_XSmall.getVenus(t: julianMillenia)
        case .earth:
            return VSOP87a_XSmall.getEarth(t: julianMillenia)
        case .earthMoonBarycenter:
            return VSOP87a_XSmall.getEmb(t: julianMillenia)
        case .moon:
            return VSOP87a_XSmall.getMoon(earth: VSOP87a_XSmall.getEarth(t: julianMillenia), emb: VSOP87a_XSmall.getEmb(t: julianMillenia))
        case .mars:
            return VSOP87a_XSmall.getMars(t: julianMillenia)
        case .jupiter:
            return VSOP87a_XSmall.getJupiter(t: julianMillenia)
        case .saturn:
            return VSOP87a_XSmall.getSaturn(t: julianMillenia)
        case .uranus:
            return VSOP87a_XSmall.getUranus(t: julianMillenia)
        case .neptune:
            return VSOP87a_XSmall.getNeptune(t: julianMillenia)
        }
    }
}
