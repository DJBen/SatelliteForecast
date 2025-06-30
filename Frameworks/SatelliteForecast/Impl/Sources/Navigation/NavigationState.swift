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
    ///   Root / Special satellite / passes
    public var passPredictionNavigationPath: NavigationPath = .init()
    /// - Satellite categories
    /// Root / category / satellite /passes
    public var satelliteCategoryNavigationPath = NavigationPath()
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
    case satellites
    case settings
}

extension Tab: Equatable, Hashable {}

public struct ListNavigation {
    public var category: SatelliteCategory
    public var selectedPassIndex: Int?
    public var showAlarmConfigurationModal: Bool
    public var showsDetailPassView: Bool

    public init(
        category: SatelliteCategory = .iss,
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
