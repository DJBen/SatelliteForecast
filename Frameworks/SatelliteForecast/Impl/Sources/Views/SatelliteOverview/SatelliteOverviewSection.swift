//
//  SatelliteOverviewSection.swift
//  SatelliteOverviewSection
//
//  Created by Ben Lu on 7/31/21.
//

import Foundation
import SatelliteForecast

public enum SatelliteOverviewSection: Equatable, Hashable {
    case satellitesOfSpecialInterest([SatelliteOverviewItem])
    case categories([SatelliteOverviewItem])

    public var items: [SatelliteOverviewItem] {
        switch self {
        case let .satellitesOfSpecialInterest(items),
            let .categories(items):
            return items
        }
    }
}

public enum SatelliteOverviewItem: Equatable, Hashable {
    public enum SatellitesOfSpecialInterest: UInt, Equatable, Hashable {
        case iss = 25544
        case tianhe = 48274
    }
    case specialSatellite(SatellitesOfSpecialInterest)
    case category(SatelliteCategory)
}

