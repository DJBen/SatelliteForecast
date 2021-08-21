//
//  NotificationReducer.swift
//  NotificationReducer
//
//  Created by Ben Lu on 8/19/21.
//

import Foundation
import os
import SwiftRex

fileprivate let logger = Logger(subsystem: "io.djben.notification", category: "reducer")

extension Reducer where ActionType == NotificationAction, StateType == NotificationState {
    static let notificationReducer = Reducer.reduce { action, state in
        switch action {
        case let .addNotification(scheduledPassNotification):
            state.scheduledPassNotifications.insert(scheduledPassNotification)
            
            let encoder = JSONEncoder()
            let notificationsData = try! encoder.encode(Array(state.scheduledPassNotifications))
            UserDefaults.standard.set(notificationsData, forKey: "scheduledLocalNotifications")
            
        case let .cancelNotifications(ids):
            state.scheduledPassNotifications = state.scheduledPassNotifications.filter { !ids.contains($0.id) }
            
        case .scheduleNotification(_):
            break
            
        case .registerNotifications:
            break
            
        case .requestNotificationAuthorization(_):
            break
                        
        case .fetchPendingNotificationRequests:
            break
            
        case let .fetchedPendingNotifications(requests):
            state.pendingNotifications = requests
            
        case .fetchDeliveredNotifications:
            break
            
        case let .fetchedDeliveredNotifications(notifications):
            state.deliveredNotifications = notifications

        case let .saveNotificationsToPersistenceStorage(scheduledNotifications):
            let encoder = JSONEncoder()
            let notificationsData = try! encoder.encode(Array(scheduledNotifications))
            UserDefaults.standard.set(notificationsData, forKey: "scheduledLocalNotifications")
            
        case .loadNotificationsFromPersistenceStorage:
            break

        case let .loadedNoficationsFromPersistenceStorage(scheduledPassNotifications):
            state.scheduledPassNotifications = scheduledPassNotifications
        }
    }
}
