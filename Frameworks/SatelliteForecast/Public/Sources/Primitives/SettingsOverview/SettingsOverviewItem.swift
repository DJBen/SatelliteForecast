//
//  SettingsOverviewItem.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/28/22.
//

import Foundation

public enum SettingsOverviewItem {
    case observer
    case alarms
}

extension SettingsOverviewItem: Hashable {}

public struct ObserverNavigationState {
    public var enabled: Bool = false

    public init(enabled: Bool = false) {
        self.enabled = enabled
    }
}

extension ObserverNavigationState: Equatable {}

public struct AlarmNavigationState {
    public var enabled: Bool = false

    public init(enabled: Bool = false) {
        self.enabled = enabled
    }
}

extension AlarmNavigationState: Equatable {}
