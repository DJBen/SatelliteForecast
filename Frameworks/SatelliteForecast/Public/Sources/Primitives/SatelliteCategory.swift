//
//  SatelliteCategory.swift
//  SatelliteCategory
//
//  Created by Ben Lu on 8/22/21.
//

import Foundation

public enum SatelliteCategory: String, Equatable, Hashable, Codable, Sendable {
    /// International Space Station: 25544
    case iss
    
    /// Tianhe: 48274
    case tianhe
    
    /// The brighest 100 (or so) satellites.
    case brightest100

    /// Satellites that are launched within last 30 days
    case last30DayLaunches

    /// All active satellites
    case active
    
    public init?(noradIndex: UInt) {
        if noradIndex == 25544 {
            self = .iss
        } else if noradIndex == 48274 {
            self = .tianhe
        } else {
            return nil
        }
    }
    
    public var noradIndex: UInt? {
        switch self {
        case .iss:
            return 25544
        case .tianhe:
            return 48274
        default:
            return nil
        }
    }
}
