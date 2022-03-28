//
//  SatelliteOverviewSection.swift
//  SatelliteOverviewSection
//
//  Created by Ben Lu on 7/31/21.
//

import Foundation

enum SatelliteOverviewSection: Equatable, Hashable {
    case satellitesOfSpecialInterest([SatelliteOverviewItem])
    case categories([SatelliteOverviewItem])

    var items: [SatelliteOverviewItem] {
        switch self {
        case let .satellitesOfSpecialInterest(items),
            let .categories(items):
            return items
        }
    }
}

enum SatelliteOverviewItem: Equatable, Hashable {
    enum SatellitesOfSpecialInterest: UInt, Equatable, Hashable {
        case iss = 25544
        case tianhe = 48274
    }
    case specialSatellites(SatellitesOfSpecialInterest)
    case category(SatelliteCategory)
}

extension NavigationState {
    var selectedSatelliteOverviewItem: SatelliteOverviewItem? {
        if let specialNoradIndex = specialSatelliteNavigation.noradIndex {
            return .specialSatellites(SatelliteOverviewItem.SatellitesOfSpecialInterest(rawValue: specialNoradIndex)!)
        } else if let category = listNavigation.category {
            return .category(category)
        } else {
            return nil
        }
    }
}
