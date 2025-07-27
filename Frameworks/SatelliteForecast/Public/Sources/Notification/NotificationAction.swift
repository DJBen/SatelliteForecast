//
//  NotificationAction.swift
//  NotificationAction
//
//  Created by Ben Lu on 8/19/21.
//

import Foundation
@preconcurrency import SatelliteKit
import UserNotifications

public enum NotificationAction {
    // MARK: Input
    
    // Persistence
    case loadNotificationsFromPersistenceStorage
    case saveNotificationsToPersistenceStorage(Set<ScheduledPassNotification>)

    // Notification center
    case registerNotifications
    case requestNotificationAuthorization(pendingNotification: PassNotification? = nil)
    case fetchPendingNotificationRequests
    case fetchDeliveredNotifications
    case generatePreviewAndScheduleNotification(PassNotification, passSnapshots: PassSnapshots)
    case removePreviewAndUnscheduleNotification(Pass)
    case scheduleNotification(PassNotification)
    case cancelNotifications(ids: Set<String>)
    
    // Deep link
    case deepLink(
        category: SatelliteCategory,
        noradIndex: UInt,
        observer: LatLonAlt,
        passIdentifier: String
    )
    
    // MARK: Output
    case loadedNotifications(Set<ScheduledPassNotification>)
    case fetchedPendingNotifications([UNNotificationRequest])
    case fetchedDeliveredNotifications([UNNotification])
    case addNotification(ScheduledPassNotification)
}
