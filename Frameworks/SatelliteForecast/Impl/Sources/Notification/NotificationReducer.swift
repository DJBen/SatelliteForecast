//
//  NotificationReducer.swift
//  NotificationReducer
//
//  Created by Ben Lu on 8/19/21.
//

import Foundation
import os
@preconcurrency import SwiftRex

fileprivate let logger = Logger(subsystem: "io.djben.notification", category: "reducer")

extension Reducer where ActionType == NotificationAction, StateType == AppState {
    public static let notificationReducer = Reducer.reduce { action, state in
        switch action {
        case let .addNotification(scheduledPassNotification):
            state.notificationResources.scheduledPassNotifications.insert(scheduledPassNotification)
            
            let encoder = JSONEncoder()
            let notificationsData = try! encoder.encode(Array(state.notificationResources.scheduledPassNotifications))
            UserDefaults.standard.set(notificationsData, forKey: "scheduledLocalNotifications")
            
        case let .cancelNotifications(ids):
            state.notificationResources.scheduledPassNotifications = state.notificationResources.scheduledPassNotifications.filter { !ids.contains($0.id) }
            
        case .scheduleNotification(_):
            break
            
        case .registerNotifications:
            break
            
        case .requestNotificationAuthorization(_):
            break
                        
        case .fetchPendingNotificationRequests:
            break
            
        case let .fetchedPendingNotifications(requests):
            state.notificationResources.pendingNotifications = requests
            
        case .fetchDeliveredNotifications:
            break
            
        case let .fetchedDeliveredNotifications(notifications):
            state.notificationResources.deliveredNotifications = notifications

        case let .saveNotificationsToPersistenceStorage(scheduledNotifications):
            let encoder = JSONEncoder()
            let notificationsData = try! encoder.encode(Array(scheduledNotifications))
            UserDefaults.standard.set(notificationsData, forKey: "scheduledLocalNotifications")
            
        case .loadNotificationsFromPersistenceStorage:
            break

        case let .loadedNotifications(scheduledPassNotifications):
            state.notificationResources.scheduledPassNotifications = scheduledPassNotifications

        case .generatePreviewAndScheduleNotification(_, passSnapshots: _):
            break

        case .removePreviewAndUnscheduleNotification(_):
            break
            
        case let .deepLink(satelliteCategory, noradIndex, observer: _, passIdentifier: _):
            state.navigationState = .init()
            switch satelliteCategory {
            case .iss, .tianhe:
                state.navigationState.tab = .forecast
                // Navigation already handled by sending event `selectSatellite`
                state.navigationState.listNavigation.category = satelliteCategory
            default:
                state.navigationState.tab = .satellites
                state.navigationState.satelliteCategoryNavigationPath.append(satelliteCategory)
                state.navigationState.listNavigation.category = satelliteCategory
            }
        }
    }
}
