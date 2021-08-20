//
//  NotificationState.swift
//  NotificationState
//
//  Created by Ben Lu on 8/20/21.
//

import Foundation
import UserNotifications

struct NotificationState: Equatable {
    var scheduledPassNotifications: Set<ScheduledPassNotification> = []
    var pendingNotifications: [UNNotificationRequest] = []
    var deliveredNotifications: [UNNotification] = []
}
