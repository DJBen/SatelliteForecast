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

    case list(category: SatelliteCategory)
    // When navigating directly from overview, the category is `nil`.
    case allPasses(category: SatelliteCategory?, noradIndex: Int)
    // When navigating directly from overview, the category is `nil`.
    case pass(category: SatelliteCategory?, noradIndex: Int, selectedPassIndex: Int)

    var selectedCategory: SatelliteCategory? {
        switch self {
        case .overview, .observer:
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
        case .list, .overview, .observer:
            return nil
        }
    }

    // MARK: - Modifications

    func selectingCategory(_ category: SatelliteCategory) -> NavigationState {
        switch self {
        case .overview:
            return .list(category: category)
        case .list(category: _),
             .allPasses(category: _, noradIndex: _),
             .pass(category: _, noradIndex: _, selectedPassIndex: _):
            return self
        case .observer:
            fatalError("Should never happen")
        }
    }

    mutating func selectCategory(_ category: SatelliteCategory) {
        self = selectingCategory(category)
    }

    func delectingSatelliteOverviewItem() -> NavigationState {
        switch self {
        case .overview:
            return self
        case .list, .allPasses(category: nil, noradIndex: _), .observer:
            return .overview
        case .pass(category: _, noradIndex: _, selectedPassIndex: _):
            fatalError("Should not happen")
        default:
            fatalError("Should not happen")
        }
    }

    mutating func deselectSatelliteOverviewItem() {
        self = delectingSatelliteOverviewItem()
    }

    func selectingObserver() -> NavigationState {
        switch self {
        case .overview:
            return .observer
        case .observer:
            return self
        case .list,
            .allPasses(category: _, noradIndex: _),
            .pass(category: _, noradIndex: _, selectedPassIndex: _):
            fatalError("Should not happen")
        }
    }

    mutating func selectObserver() {
        self = selectingObserver()
    }

    func selectingNoradIndex(_ noradIndex: Int) -> NavigationState {
        switch self {
        case .overview:
            return .allPasses(category: nil, noradIndex: noradIndex)
        case let .list(category):
            return .allPasses(category: category, noradIndex: noradIndex)
        case .allPasses(category: _, noradIndex: _),
                .pass(category: _, noradIndex: _, selectedPassIndex: _),
                .observer:
            fatalError("Should not happen")
        }
    }

    mutating func selectNoradIndex(_ noradIndex: Int) {
        self = selectingNoradIndex(noradIndex)
    }

    func deselectingNoradIndex() -> NavigationState {
        switch self {
        case .overview, .observer:
            fatalError("Should not happen")
        case .list(category: _):
            return self
        case let .allPasses(category, noradIndex: _):
            if let category = category {
                return .list(category: category)
            } else {
                return .overview
            }
        case .pass(category: _, noradIndex: _, selectedPassIndex: _):
            fatalError("Should not happen")
        }
    }

    mutating func deselectNoradIndex() {
        self = deselectingNoradIndex()
    }

    func selectingPassIndex(_ index: Int) -> NavigationState {
        switch self {
        case .overview, .observer:
            fatalError("Should not happen")
        case .list(category: _):
            fatalError("Should not happen")
        case let .allPasses(category, noradIndex):
            return .pass(category: category, noradIndex: noradIndex, selectedPassIndex: index)
        case .pass(category: _, noradIndex: _, selectedPassIndex: _):
            fatalError("Should not happen")
        }
    }

    mutating func selectPassIndex(_ index: Int) {
        self = selectingPassIndex(index)
    }

    func deselectingPassIndex() -> NavigationState {
        switch self {
        case .overview, .observer:
            fatalError("Should not happen")
        case .list(category: _):
            fatalError("Should not happen")
        case .allPasses(category: _, noradIndex: _):
            fatalError("Should not happen")
        case let .pass(category, noradIndex, _):
            return .allPasses(category: category, noradIndex: noradIndex)
        }
    }

    mutating func deselectPassIndex() {
        self = deselectingPassIndex()
    }

}
