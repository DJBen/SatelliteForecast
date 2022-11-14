//
//  NavigationState.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/27/21.
//

import Foundation
import SatelliteKit
import SatelliteForecast
import SwiftUI

struct NavigationState {
    var tab: Tab = .forecast
    var path: NavigationPath = .init()
    var specialSatelliteNavigation: SpecialSatelliteNavigation = .init()
    var listNavigation: ListNavigation = .init()
    var observerNavigation: ObserverNavigationState = .init()
    var alarmNavigation: AlarmNavigationState = .init()

    var selectedNoradIndex: UInt? {
        return specialSatelliteNavigation.noradIndex ?? listNavigation.noradIndex
    }
}

extension NavigationState: Equatable {}

enum Tab {
    case realtimeSky
    case forecast
    case settings
}

extension Tab: Equatable, Hashable {}

struct SpecialSatelliteNavigation {
    var noradIndex: UInt?

    init(
        noradIndex: UInt? = nil
    ) {
        self.noradIndex = noradIndex
    }
}

extension SpecialSatelliteNavigation: Equatable {}

struct ListNavigation {
    var satelliteSearchText: String = ""
    var category: SatelliteCategory?
    var noradIndex: UInt?
    var selectedPassIndex: Int?
    var showAlarmConfigurationModal: Bool
    var showsDetailPassView: Bool

    init(
        category: SatelliteCategory? = nil,
        noradIndex: UInt? = nil,
        selectedPassIndex: Int? = nil,
        showAlarmConfigurationModal: Bool = false,
        showsDetailPassView: Bool = false
    ) {
        self.category = category
        self.noradIndex = noradIndex
        self.selectedPassIndex = selectedPassIndex
        self.showAlarmConfigurationModal = showAlarmConfigurationModal
        self.showsDetailPassView = showsDetailPassView
    }
}

extension ListNavigation: Equatable {}
