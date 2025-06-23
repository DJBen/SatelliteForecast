//
//  NavigationState.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/27/21.
//

import Foundation
@preconcurrency import SatelliteKit
import SatelliteForecast
import SwiftUI

public struct NavigationState {
    public var tab: Tab = .forecast
    /// The navigation path for the navigation stack within pass prediction.
    /// - Pass forecast:
    ///   Root / (Special satellite | (category / satellite)) / pass
    public var passPredictionNavigationPath: NavigationPath = .init()
    /// The navigation path for the navigation stack within settings.
    /// - Settings:
    ///   Root / (Location | Alarm)
    public var settingsNavigationPath: NavigationPath = .init()
    public var listNavigation: ListNavigation = .init()
}

extension NavigationState: Equatable {}

public enum Tab {
    case realtimeSky
    case forecast
    case settings
}

extension Tab: Equatable, Hashable {}

public struct ListNavigation {
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
