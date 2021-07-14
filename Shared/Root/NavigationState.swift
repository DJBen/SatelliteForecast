//
//  NavigationState.swift
//  SatelliteForcast
//
//  Created by Ben Lu on 6/27/21.
//

import Foundation
import SatelliteKit
import SatelliteForcastCore

struct NavigationIndexPath: Equatable, Hashable {
    let category: SatelliteCategory?
    let noradIndex: Int?
    let selectedPassIndex: Int?

    init(
        category: SatelliteCategory? = nil,
        noradIndex: Int? = nil,
        selectedPassIndex: Int? = nil
    ) {
        self.category = category
        self.noradIndex = noradIndex
        self.selectedPassIndex = selectedPassIndex
    }
}

enum NavigationState: Equatable {
    case overview
    case list(category: SatelliteCategory)
    // When navigating directly from overview, the category is `nil`.
    case allPasses(category: SatelliteCategory?, noradIndex: Int)
    // When navigating directly from overview, the category is `nil`.
    case pass(category: SatelliteCategory?, noradIndex: Int, selectedPassIndex: Int)

    var indexPath: NavigationIndexPath {
        get {
            switch self {
            case .overview:
                return NavigationIndexPath(category: nil, noradIndex: nil, selectedPassIndex: nil)
            case let .list(category):
                return NavigationIndexPath(category: category, noradIndex: nil, selectedPassIndex: nil)
            case let .allPasses(category, noradIndex):
                return NavigationIndexPath(category: category, noradIndex: noradIndex, selectedPassIndex: nil)
            case let .pass(category, noradIndex, selectedPassIndex):
                return NavigationIndexPath(category: category, noradIndex: noradIndex, selectedPassIndex: selectedPassIndex)
            }
        }

        set {
            if let noradIndex = newValue.noradIndex {
                if let selectedPassIndex = newValue.selectedPassIndex {
                    self = .pass(category: newValue.category, noradIndex: noradIndex, selectedPassIndex: selectedPassIndex)
                } else {
                    self = .allPasses(category: newValue.category, noradIndex: noradIndex)
                }
            } else {
                if let category = newValue.category {
                    self = .list(category: category)
                } else {
                    self = .overview
                }
            }
        }
    }

    var selectedCategory: SatelliteCategory? {
        switch self {
        case .overview:
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
        case .list, .overview:
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
        }
    }

    mutating func selectCategory(_ category: SatelliteCategory) {
        self = selectingCategory(category)
    }

    func deselectingCategory() -> NavigationState {
        switch self {
        case .overview:
            return self
        case .list:
            return .overview
        case .allPasses(category: _, noradIndex: _):
            fatalError("Should not happen")
        case .pass(category: _, noradIndex: _, selectedPassIndex: _):
            fatalError("Should not happen")
        }
    }

    mutating func deselectCategory() {
        self = deselectingCategory()
    }

    func selectingNoradIndex(_ noradIndex: Int) -> NavigationState {
        switch self {
        case .overview:
            return .allPasses(category: nil, noradIndex: noradIndex)
        case let .list(category):
            return .allPasses(category: category, noradIndex: noradIndex)
        case .allPasses(category: _, noradIndex: _):
            fatalError("Should not happen")
        case .pass(category: _, noradIndex: _, selectedPassIndex: _):
            fatalError("Should not happen")
        }
    }

    mutating func selectNoradIndex(_ noradIndex: Int) {
        self = selectingNoradIndex(noradIndex)
    }

    func deselectingNoradIndex() -> NavigationState {
        switch self {
        case .overview:
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
        case .overview:
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
        case .overview:
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
