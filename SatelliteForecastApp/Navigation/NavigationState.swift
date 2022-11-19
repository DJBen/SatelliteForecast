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
    /// The navigation path for the navigation stack.
    /// - Pass forecast:
    ///   Root / (Special satellite | (category / satellite)) / pass
    /// - Settings:
    ///   Root / (Location | Alarm)
    var navigationPath: NavigationPath = .init()
    var listNavigation: ListNavigation = .init()
    var observerNavigation: ObserverNavigationState = .init()
    var alarmNavigation: AlarmNavigationState = .init()
}

extension NavigationState: Equatable {}

enum Tab {
    case realtimeSky
    case forecast
    case settings
}

extension Tab: Equatable, Hashable {}

struct ListNavigation {
    var satelliteSearchText: String = ""
    var category: SatelliteCategory?
    var selectedPassIndex: Int?
    var showAlarmConfigurationModal: Bool
    var showsDetailPassView: Bool

    init(
        category: SatelliteCategory? = nil,
        selectedPassIndex: Int? = nil,
        showAlarmConfigurationModal: Bool = false,
        showsDetailPassView: Bool = false
    ) {
        self.category = category
        self.selectedPassIndex = selectedPassIndex
        self.showAlarmConfigurationModal = showAlarmConfigurationModal
        self.showsDetailPassView = showsDetailPassView
    }
}

extension ListNavigation: Equatable {}
