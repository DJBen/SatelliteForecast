//
//  NotificationResources.swift
//  NotificationResources
//
//  Created by Ben Lu on 8/20/21.
//

import Foundation
import SatelliteForecast
import UserNotifications

public struct NotificationResources: Equatable {
    public var scheduledPassNotifications: Set<ScheduledPassNotification> = []
    public var pendingNotifications: [UNNotificationRequest] = []
    public var deliveredNotifications: [UNNotification] = []
    
    /// All the things to deep link to a pass.
    public struct PassDeepLink: Equatable {
        var satelliteCategory: SatelliteCategory?
        var noradIndex: UInt
        var passIdentifier: String
    }
}
