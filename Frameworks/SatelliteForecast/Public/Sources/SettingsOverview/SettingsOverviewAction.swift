import SwiftUI

public enum SettingsOverviewViewAction {
    case navigate(NavigationPath)
    case setNightMode(Bool)
    case setExperimentalSkyNow(Bool)
}

extension SettingsOverviewViewAction: Equatable {}
