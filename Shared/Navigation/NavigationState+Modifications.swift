//
//  NavigationState+Modifications.swift
//  NavigationState+Modifications
//
//  Created by Ben Lu on 8/23/21.
//

import Foundation

extension NavigationState {
    mutating func selectSatellite(noradIndex: Int) {
        switch self {
        case .overview:
            self = .allPasses(category: nil, noradIndex: noradIndex)
        case let .list(category):
            self = .allPasses(category: category, noradIndex: noradIndex)
        case .allPasses(category: _, noradIndex: _),
            .pass(category: _, noradIndex: _, selectedPassIndex: _),
            .observer,
            .alarm:
            fatalError("Should not happen")
        }
    }
    
    mutating func deselectSatellite() {
        switch self {
        case .overview, .observer, .alarm:
            fatalError("Should not happen")
        case .list(category: _):
            break
        case let .allPasses(category, noradIndex: _):
            if let category = category {
                self = .list(category: category)
            } else {
                self = .overview
            }
        case .pass(category: _, noradIndex: _, selectedPassIndex: _):
            fatalError("Should not happen")
        }
    }
    
    mutating func returnToSatelliteOverview() {
        switch self {
        case .overview:
            break
        case .list, .allPasses(category: nil, noradIndex: _), .observer, .alarm:
            self = .overview
        case .pass(category: _, noradIndex: _, selectedPassIndex: _):
            fatalError("Should not happen")
        default:
            fatalError("Should not happen")
        }
    }
    
    mutating func selectSatelliteCategory(category: SatelliteCategory) {
        switch self {
        case .overview:
            self = .list(category: category)
        case .list(category: _),
             .allPasses(category: _, noradIndex: _),
             .pass(category: _, noradIndex: _, selectedPassIndex: _):
            break
        case .observer, .alarm:
            fatalError("Should never happen")
        }
    }
    
    mutating func selectPass(index: Int) {
        switch self {
        case .overview, .observer, .alarm:
            fatalError("Should not happen")
        case .list(category: _):
            fatalError("Should not happen")
        case let .allPasses(category, noradIndex):
            self = .pass(category: category, noradIndex: noradIndex, selectedPassIndex: index)
        case .pass(category: _, noradIndex: _, selectedPassIndex: _):
            fatalError("Should not happen")
        }
    }
    
    mutating func deselectPass() {
        switch self {
        case .overview, .observer, .alarm:
            fatalError("Should not happen")
        case .list(category: _):
            fatalError("Should not happen")
        case .allPasses(category: _, noradIndex: _):
            fatalError("Should not happen")
        case let .pass(category, noradIndex, _):
            self = .allPasses(category: category, noradIndex: noradIndex)
        }
    }
    
    mutating func selectLocationSettings() {
        switch self {
        case .overview:
            self = .observer
        case .observer:
            break
        case .list,
            .allPasses(category: _, noradIndex: _),
            .pass(category: _, noradIndex: _, selectedPassIndex: _),
            .alarm:
            fatalError("Should not happen")
        }
    }
    
    mutating func dismissLocationSettings() {
        switch self {
        case .overview:
            break
        case .observer:
            self = .overview
        case .list,
            .allPasses(category: _, noradIndex: _),
            .pass(category: _, noradIndex: _, selectedPassIndex: _),
            .alarm:
            fatalError("Should not happen")
        }
    }
    
    mutating func showAlertSettings() {
        switch self {
        case .overview:
            self = .alarm
        case .alarm:
            break
        case .list,
            .allPasses(category: _, noradIndex: _),
            .pass(category: _, noradIndex: _, selectedPassIndex: _),
            .observer:
            fatalError("Should not happen")
        }
    }
    
    mutating func dismissAlertSettings() {
        switch self {
        case .overview:
            break
        case .alarm:
            self = .overview
        case .list,
            .allPasses(category: _, noradIndex: _),
            .pass(category: _, noradIndex: _, selectedPassIndex: _),
            .observer:
            fatalError("Should not happen")
        }
    }
}
