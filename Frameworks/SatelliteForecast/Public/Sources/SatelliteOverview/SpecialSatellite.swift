/// Used in `SatelliteOverviewView` as navigation path item,
/// in lieu of raw `SatelliteCategory`, which is overlapping with satellite list's navigation.
public enum SpecialSatellite: UInt, Equatable, Hashable, Sendable {
    case iss = 25544
    case tianhe = 48274
    
    public init?(_ satelliteCategory: SatelliteCategory) {
        switch satelliteCategory {
        case .iss:
            self = .iss
        case .tianhe:
            self = .tianhe
        default:
            return nil
        }
    }
    
    public var category: SatelliteCategory {
        switch self {
        case .iss:
            return .iss
        case .tianhe:
            return .tianhe
        }
    }
}

