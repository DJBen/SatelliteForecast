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
            return VSOP87a_XSmall.getMercury(julianMillenia)
        case .venus:
            return VSOP87a_XSmall.getVenus(julianMillenia)
        case .earth:
            return VSOP87a_XSmall.getEarth(julianMillenia)
        case .earthMoonBarycenter:
            return VSOP87a_XSmall.getEmb(julianMillenia)
        case .moon:
            return VSOP87a_XSmall.getMoon(earth: VSOP87a_XSmall.getEarth(julianMillenia), emb: VSOP87a_XSmall.getEmb(julianMillenia))
        case .mars:
            return VSOP87a_XSmall.getMars(julianMillenia)
        case .jupiter:
            return VSOP87a_XSmall.getJupiter(julianMillenia)
        case .saturn:
            return VSOP87a_XSmall.getSaturn(julianMillenia)
        case .uranus:
            return VSOP87a_XSmall.getUranus(julianMillenia)
        case .neptune:
            return VSOP87a_XSmall.getNeptune(julianMillenia)
        }
    }
}
