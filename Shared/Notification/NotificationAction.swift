//
//  NotificationAction.swift
//  NotificationAction
//
//  Created by Ben Lu on 8/19/21.
//

import Foundation
import SatelliteForecastCore
import SatelliteKit
import UserNotifications

enum NotificationAction {
    // MARK: Input
    
    // Persistence
    case loadNotificationsFromPersistenceStorage
    case saveNotificationsToPersistenceStorage(Set<ScheduledPassNotification>)
    
    // Notification center
    case registerNotifications
    case requestNotificationAuthorization(pendingNotification: PassNotification? = nil)
    case fetchPendingNotificationRequests
    case fetchedPendingNotifications([UNNotificationRequest])
    case fetchDeliveredNotifications
    case fetchedDeliveredNotifications([UNNotification])
    case scheduleNotification(PassNotification)
    case cancelNotifications(ids: Set<String>)
    
    // MARK: Output
    case addNotification(ScheduledPassNotification)
}
