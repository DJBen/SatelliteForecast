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

extension Reducer where ActionType == NotificationAction, StateType == AppState {
    static let notificationReducer = Reducer.reduce { action, state in
        switch action {
        case let .addNotification(scheduledPassNotification):
            state.notificationState.scheduledPassNotifications.insert(scheduledPassNotification)
            
            let encoder = JSONEncoder()
            let notificationsData = try! encoder.encode(Array(state.notificationState.scheduledPassNotifications))
            UserDefaults.standard.set(notificationsData, forKey: "scheduledLocalNotifications")
            
        case let .cancelNotifications(ids):
            state.notificationState.scheduledPassNotifications = state.notificationState.scheduledPassNotifications.filter { !ids.contains($0.id) }
            
        case .scheduleNotification(_):
            break
            
        case .registerNotifications:
            break
            
        case .requestNotificationAuthorization(_):
            break
                        
        case .fetchPendingNotificationRequests:
            break
            
        case let .fetchedPendingNotifications(requests):
            state.notificationState.pendingNotifications = requests
            
        case .fetchDeliveredNotifications:
            break
            
        case let .fetchedDeliveredNotifications(notifications):
            state.notificationState.deliveredNotifications = notifications

        case let .saveNotificationsToPersistenceStorage(scheduledNotifications):
            let encoder = JSONEncoder()
            let notificationsData = try! encoder.encode(Array(scheduledNotifications))
            UserDefaults.standard.set(notificationsData, forKey: "scheduledLocalNotifications")
            
        case .loadNotificationsFromPersistenceStorage:
            break

        case let .loadedNotifications(scheduledPassNotifications):
            state.notificationState.scheduledPassNotifications = scheduledPassNotifications
            
        case let .deepLink(satelliteCategory, noradIndex, observer: _, passIdentifier: _):
            if let satelliteCategory = satelliteCategory {
                state.navigationState.listNavigation = ListNavigation(
                    category: satelliteCategory,
                    noradIndex: noradIndex
                )
                state.navigationState.specialSatelliteNavigation = .init()
            } else {
                state.navigationState.listNavigation = .init()
                state.navigationState.specialSatelliteNavigation.noradIndex = noradIndex
            }
        }
    }
}
