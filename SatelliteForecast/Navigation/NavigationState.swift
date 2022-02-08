//
//  NavigationState.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/27/21.
//

import Foundation
import SatelliteKit
import SatelliteForecastCore

struct NavigationState {
    var specialSatelliteNavigation: SpecialSatelliteNavigation = .init()
    var listNavigation: ListNavigation = .init()
    var observerNavigation: ObserverNavigationState = .init()
    var alarmNavigation: AlarmNavigationState = .init()

    var selectedNoradIndex: Int? {
        return specialSatelliteNavigation.noradIndex ?? listNavigation.noradIndex
    }
}

extension NavigationState: Equatable {}

struct SpecialSatelliteNavigation {
    var noradIndex: Int?

    init(
        noradIndex: Int? = nil
    ) {
        self.noradIndex = noradIndex
    }
}

extension SpecialSatelliteNavigation: Equatable {}

struct ListNavigation {
    var satelliteSearchText: String = ""
    var category: SatelliteCategory?
    var noradIndex: Int?
    var selectedPassIndex: Int?

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

extension ListNavigation: Equatable {}

struct ObserverNavigationState {
    var enabled: Bool = false
}

extension ObserverNavigationState: Equatable {}

struct AlarmNavigationState {
    var enabled: Bool = false
}

extension AlarmNavigationState: Equatable {}
