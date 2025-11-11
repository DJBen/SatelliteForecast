//
//  DebugMenuAction.swift
//  SatelliteForecastPackage
//
//  Created by Sihao Lu on 7/27/25.
//

public enum DebugMenuAction {
    case toggleDebugMenu(_ isVisible: Bool)

    case toggleFreezeTime(_ isOn: Bool)
    case toggleMockedOffset(_ isOn: Bool)
    case setMockedDateOffset(_ offset: Double)
    case toggleRapidNotificationDelivery(_ isOn: Bool)
    case toggleSimulateTLEFailure(_ isOn: Bool)
    
    case fetchNotifications
    
    case triggerPassDeepLink(category: SatelliteCategory, noradIndex: UInt)
    
    case resetOnboarding
    case resetMainOnboarding
    case resetAllPassesOnboarding
}
