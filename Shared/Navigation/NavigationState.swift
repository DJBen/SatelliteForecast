//
//  NavigationState.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/27/21.
//

import Foundation
import SatelliteKit
import SatelliteForecastCore

enum NavigationState: Equatable {
    /// The satellite overview screen; also the homepage.
    case overview
    /// The observer configuration screen.
    case observer
    /// The alarm configuration screen.
    case alarm

    case list(category: SatelliteCategory)
    // When navigating directly from overview, the category is `nil`.
    case allPasses(category: SatelliteCategory?, noradIndex: Int)
    // When navigating directly from overview, the category is `nil`.
    case pass(category: SatelliteCategory?, noradIndex: Int, selectedPassIndex: Int)

    var selectedCategory: SatelliteCategory? {
        switch self {
        case .overview, .observer, .alarm:
            return nil
        case let .list(category):
            return category
        case let .allPasses(category, noradIndex: _):
            return category
        case let .pass(category, noradIndex: _, selectedPassIndex: _):
            return category
        }
    }

    var selectedSatelliteNoradIndex: Int? {
        switch self {
        case let .allPasses(_, noradIndex), let .pass(_, noradIndex, _):
            return noradIndex
        case .list, .overview, .observer, .alarm:
            return nil
        }
    }
}
