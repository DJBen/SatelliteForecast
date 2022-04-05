//
//  NotificationResources.swift
//  NotificationResources
//
//  Created by Ben Lu on 8/20/21.
//

import Foundation
import SatelliteForecast
import SatelliteForecastImpl
import UserNotifications

struct NotificationResources: Equatable {
    var scheduledPassNotifications: Set<ScheduledPassNotification> = []
    var pendingNotifications: [UNNotificationRequest] = []
    var deliveredNotifications: [UNNotification] = []
    
    /// All the things to deep link to a pass.
    struct PassDeepLink: Equatable {
        var satelliteCategory: SatelliteCategory?
        var noradIndex: UInt
        var passIdentifier: String
    }
}
