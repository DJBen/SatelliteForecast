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
    case observerSettings([SatelliteOverviewItem])

    var items: [SatelliteOverviewItem] {
        switch self {
        case let .satellitesOfSpecialInterest(items),
             let .categories(items),
             let .observerSettings(items):
            return items
        }
    }
}

enum SatelliteOverviewItem: Equatable, Hashable {
    enum SatellitesOfSpecialInterest: Int, Equatable, Hashable {
        case iss = 25544
        case tianhe = 48274
    }
    case specialSatellites(SatellitesOfSpecialInterest)
    case category(SatelliteCategory)

    enum Management: Equatable, Hashable {
        case observer
        case alert
    }
    case observerSettings
}

extension NavigationState {
    var selectedSatelliteOverviewItem: SatelliteOverviewItem? {
        switch self {
        case .overview:
            return nil
        case let .list(category):
            return .category(category)
        case let .allPasses(category, noradIndex), let .pass(category, noradIndex, _):
            if let category = category {
                return .category(category)
            } else {
                return .specialSatellites(SatelliteOverviewItem.SatellitesOfSpecialInterest(rawValue: noradIndex)!)
            }
        case .observer:
            return .observerSettings
        }
    }
}
