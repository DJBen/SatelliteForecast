//
//  NotificationMiddleware.swift
//  NotificationMiddleware
//
//  Created by Ben Lu on 8/19/21.
//

import BTree
import Combine
import CombineRex
import Foundation
import os
import SatelliteForecastCore
import SatelliteKit
import SwiftDate
import UserNotifications

fileprivate let logger = Logger(subsystem: "io.djben.notification", category: "middleware")

extension EffectMiddleware where
    InputActionType == NotificationAction,
    OutputActionType == AppAction,
    StateType == AppState,
    Dependencies == Void {

    static var notification: EffectMiddleware<NotificationAction, AppAction, AppState, Void> {
        EffectMiddleware<NotificationAction, AppAction, AppState, Void>.onAction { action, _, getState in
            switch action {
            case let .scheduleNotification(passNotification):
                return Effect { context -> AnyPublisher<DispatchedAction<AppAction>, Never> in
                    let subject = PassthroughSubject<DispatchedAction<AppAction>, Never>()

                    let dateComponents = Date(julianDate: passNotification.pass.rise.julianDate).dateComponents
                    let julianDateDiff = passNotification.pass.rise.julianDate - getState().julianDate
                    let timeInterval = getState().debugMenu.rapidNotificationDelivery ? 10 : julianDateDiff * TimeConstants.day2sec
                    let trigger = UNTimeIntervalNotificationTrigger(
                        timeInterval: timeInterval,
                        repeats: false
                    )

                    let content = UNMutableNotificationContent()
                    content.categoryIdentifier = "PASS"
                    content.title = LocalizedStrings.Notification.title(passNotification: passNotification)
                    content.body = LocalizedStrings.Notification.description(passNotification: passNotification)
                    let encoder = JSONEncoder()
                    content.userInfo = [
                        "satelliteCategory": try! encoder.encode(passNotification.category),
                        "noradIndex": passNotification.pass.noradIndex,
                        "observer": try! encoder.encode(passNotification.observer)
                    ]
                    
                    if let attachment = try? UNNotificationAttachment(
                        identifier: "\(passNotification.pass.notificationIdentifier)_attachment",
                        url: passNotification.pass.attachmentImageURL(extension: "png"),
                        options: [:]
                    ) {
                        content.attachments = [attachment]
                    } else {
                        logger.error("Failed to attach \(passNotification.pass.attachmentImageURL(extension: "png"))")
                    }
                    
                    let request = UNNotificationRequest(
                        identifier: passNotification.pass.notificationIdentifier,
                        content: content,
                        trigger: trigger
                    )

                    // Schedule the request with the system.
                    let notificationCenter = UNUserNotificationCenter.current()
                    notificationCenter.add(request) { (error) in
                        if let error = error {
                            logger.error("Failed to schedule local notification for \(passNotification.pass.noradIndex) at \(dateComponents): \(error.localizedDescription)")
                        } else {
                            let scheduledPassNotification = ScheduledPassNotification(
                                id: passNotification.pass.notificationIdentifier,
                                notification: passNotification
                            )
                            
                            subject.send(DispatchedAction<AppAction>(.notification(.addNotification(scheduledPassNotification))))
                        }
                        
                        subject.send(completion: .finished)
                    }
                    
                    return subject.eraseToAnyPublisher()
                }
                
            case let .cancelNotifications(ids):
                return .fireAndForget {
                    let notificationCenter = UNUserNotificationCenter.current()

                    notificationCenter.removePendingNotificationRequests(withIdentifiers: Array(ids))
                }
                
            case .registerNotifications:
                return .fireAndForget {
                    let passCategory = UNNotificationCategory(
                        identifier: "PASS",
                        actions: [],
                        intentIdentifiers: [],
                        options: []
                    )
                    
                    let center = UNUserNotificationCenter.current()
                    center.setNotificationCategories([passCategory])
                }
                
            case let .requestNotificationAuthorization(pendingNotification):
                return Effect { context -> AnyPublisher<DispatchedAction<AppAction>, Never> in
                    let subject = PassthroughSubject<DispatchedAction<AppAction>, Never>()
                    
                    let center = UNUserNotificationCenter.current()
                    center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                        defer {
                            subject.send(completion: .finished)
                        }
                        
                        if let error = error {
                            logger.error("Failed to request authorization: \(error.localizedDescription)")
                            return
                        }
                        
                        if granted {
                            if let pendingNotification = pendingNotification {
                                subject.send(DispatchedAction<AppAction>(.notification(.scheduleNotification(pendingNotification))))
                            }
                        }
                    }
                    
                    return subject.eraseToAnyPublisher()
                }
                
            case .addNotification(_):
                return .doNothing
                
            case .fetchPendingNotificationRequests:
                return Effect { context -> AnyPublisher<DispatchedAction<AppAction>, Never> in
                    let subject = PassthroughSubject<DispatchedAction<AppAction>, Never>()

                    UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                        subject.send(DispatchedAction<AppAction>(.notification(.fetchedPendingNotifications(requests))))
                        subject.send(completion: .finished)
                    }
                    
                    return subject.eraseToAnyPublisher()
                }
                
            case .fetchedPendingNotifications(_):
                return .doNothing
                
            case .fetchDeliveredNotifications:
                return Effect { context -> AnyPublisher<DispatchedAction<AppAction>, Never> in
                    let subject = PassthroughSubject<DispatchedAction<AppAction>, Never>()

                    UNUserNotificationCenter.current().getDeliveredNotifications { requests in
                        subject.send(DispatchedAction<AppAction>(.notification(.fetchedDeliveredNotifications(requests))))
                        subject.send(completion: .finished)
                    }
                    
                    return subject.eraseToAnyPublisher()
                }
                
            case .fetchedDeliveredNotifications(_):
                return .doNothing

            case .loadNotificationsFromPersistenceStorage:
                return Effect { context -> AnyPublisher<DispatchedAction<AppAction>, Never> in
                    let subject = PassthroughSubject<DispatchedAction<AppAction>, Never>()

                    let decoder = JSONDecoder()
                    let notifications = (UserDefaults.standard.object(forKey: "scheduledLocalNotifications") as? Data).flatMap {
                        try? decoder.decode([ScheduledPassNotification].self, from: $0)
                    }
                    .map(Set.init) ?? []
                    
                    UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                        // Leave pending notifications and remove the already delivered ones
                        let pendingNotifications = notifications.filter {
                            requests.map(\.identifier).contains($0.id)
                        }
                        
                        subject.send(DispatchedAction<AppAction>(.notification(.loadedNotifications(pendingNotifications))))
                        
                        let invalidNotifications = notifications.filter {
                            !requests.map(\.identifier).contains($0.id)
                        }
                        
                        for notification in invalidNotifications {
                            let imageURL = notification.notification.pass.attachmentImageURL(extension: "png")
                            do {
                                try FileManager.default.removeItem(at: imageURL)
                                logger.info("Cleared delivered notification attachment at \(imageURL)")
                            } catch {
                                
                            }
                        }
                        
                        subject.send(completion: .finished)
                    }

                    return subject.eraseToAnyPublisher()
                }
                
            case .loadedNotifications(_):
                return .doNothing

            case .saveNotificationsToPersistenceStorage(_):
                return .doNothing
                
            case let .deepLink(satelliteCategory, noradIndex, observer, passIdentifier: _):
                return Effect { context -> AnyPublisher<DispatchedAction<AppAction>, Never> in
                    let subject = PassthroughSubject<DispatchedAction<AppAction>, Never>()

                    DispatchQueue.global().async {
                        func calculatePass(infoMap: Map<Int, SatelliteInfo>) -> AppAction? {
                            guard let satelliteInfo = infoMap[noradIndex] else {
                                return nil
                            }
                            return .allPassesView(
                                .calculatePasses(
                                    .init(
                                        selectedNoradIndex: noradIndex,
                                        satelliteInfo: satelliteInfo,
                                        julianDateRange: JulianDateUtil.createJulianDateRange(now: getState().julianDate),
                                        observer: observer
                                    )
                                )
                            )
                        }
                        if let category = satelliteCategory {
                            subject.send(
                                DispatchedAction(.satelliteLoader(
                                    .loadSatelliteCategory(
                                        category,
                                        calculatePass: SatelliteLoaderCalculatePassParam(
                                            noradID: noradIndex,
                                            dateRange: JulianDateUtil.createJulianDateRange(now: getState().julianDate),
                                            observer: observer
                                        )
                                    )
                                ))
                            )
                        } else {
                            subject.send(
                                DispatchedAction(.satelliteLoader(
                                    .loadSatelliteCategory(
                                        .brightest100,
                                        calculatePass: SatelliteLoaderCalculatePassParam(
                                            noradID: noradIndex,
                                            dateRange: JulianDateUtil.createJulianDateRange(now: getState().julianDate),
                                            observer: observer
                                        )
                                    )
                                ))
                            )
                        }
                        subject.send(completion: .finished)
                    }
                                        
                    return subject.eraseToAnyPublisher()
                }
            }
        }
    }
}
