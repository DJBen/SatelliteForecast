//
//  NotificationMiddleware.swift
//  NotificationMiddleware
//
//  Created by Ben Lu on 8/19/21.
//

import BTree
import Combine
@preconcurrency import CombineRex
import Foundation
import os
import SatelliteForecast
import SatelliteForecastImpl
@preconcurrency import SatelliteKit
import SatelliteCatalog
import StarryNight
import UserNotifications
import UIKit

fileprivate let logger = Logger(subsystem: "io.djben.notification", category: "middleware")

public struct NotificationMiddlewareDependencies {
    public let dateProvider: () -> Date

    public init(dateProvider: @escaping () -> Date) {
        self.dateProvider = dateProvider
    }
}

extension EffectMiddleware where
    InputActionType == NotificationAction,
    OutputActionType == AppAction,
    StateType == AppState,
    Dependencies == Void {

    public typealias NotificationEffectMiddleware = EffectMiddleware<NotificationAction, AppAction, AppState, NotificationMiddlewareDependencies>

    public static var notification: MiddlewareReader<NotificationMiddlewareDependencies, NotificationEffectMiddleware> {
        NotificationEffectMiddleware.onAction { action, dispatcher, getState in
            switch action {
            case .generatePreviewAndScheduleNotification(let passNotification, let passSnapshots):
                return Effect { context -> AnyPublisher<DispatchedAction<AppAction>, Never> in
                    let subject = PassthroughSubject<DispatchedAction<AppAction>, Never>()
                    let pass = passNotification.pass

                    DispatchQueue.global(qos: .userInitiated).async {
                        // Force dark theme
                        let traitCollection = UITraitCollection(userInterfaceStyle: .dark)
                        traitCollection.performAsCurrent {
                            let rect = CGRect(x: 0, y: 0, width: 350, height: 350)
                            let imageRect = rect.insetBy(dx: 5, dy: 5)
                            let renderer = UIGraphicsImageRenderer(size: rect.size)
                            let image = renderer.image { ctx in
                                SkyChartUtils.addRasterizedBackgroundSkyPath(
                                    to: ctx,
                                    params: BackgroundSkyRenderParams(
                                        rect: imageRect,
                                        stars: Star.magitudeLessThan(4),
                                        constellations: Constellation.all,
                                        observer: passNotification.observer,
                                        julianDate: pass.rise.julianDate,
                                        starColor: SkyChartTheme.starColor(
                                            traitCollection: traitCollection
                                        ),
                                        constellationLineColor: SkyChartTheme.constellationLineColor(
                                            traitCollection: traitCollection
                                        ),
                                        drawPlanaryBodies: true,
                                        backgroundFillColor: UIColor.secondarySystemBackground,
                                        border: BackgroundSkyRenderParams.Border(
                                            borderColor: SkyChartTheme.skyChartStrokeColor(
                                                traitCollection: traitCollection
                                            )
                                        ),
                                        magToRadius: { CGFloat(3 * exp(-0.425 * $0)) }
                                    )
                                )

                                SkyChartUtils.addRasterizedSatellitePassPath(
                                    to: ctx,
                                    params: SatellitePassPathRenderParams(
                                        rect: imageRect,
                                        snapshotsDuringPass: passSnapshots.snapshots,
                                        illuminatedColor: SkyChartTheme.satellitePathColor(
                                            illuminated: true,
                                            traitCollection: traitCollection
                                        ),
                                        unlitColor: SkyChartTheme.satellitePathColor(
                                            illuminated: false,
                                            traitCollection: traitCollection
                                        )
                                    )
                                )
                            }

                            do {
                                let imageURL = pass.attachmentImageURL(extension: "png")

                                guard let data = image.pngData() else {
                                    subject.send(
                                        DispatchedAction(
                                            .notification(
                                                .requestNotificationAuthorization(
                                                    pendingNotification: passNotification
                                                )
                                            )
                                        )
                                    )
                                    subject.send(completion: .finished)
                                    return
                                }

                                try data.write(to: imageURL)
                                logger.info("Generated alarm attachment \(imageURL)")

                                subject.send(
                                    DispatchedAction(
                                        .notification(
                                            .requestNotificationAuthorization(pendingNotification: passNotification)
                                        )
                                    )
                                )
                                subject.send(completion: .finished)

                            } catch {
                                logger.error("Failed to save alarm attachment: \(error.localizedDescription)")
                                subject.send(
                                    DispatchedAction(
                                        .notification(
                                            .requestNotificationAuthorization(pendingNotification: passNotification)
                                        )
                                    )
                                )
                                subject.send(completion: .finished)
                            }
                        }
                    }

                    // Make sure that the request finishes at least 0.75 seconds after triggering,
                    // leaving enough time for the animation to complete
                    let timerFuture = Future<Void, Never> { sink in
                        DispatchQueue.global().asyncAfter(deadline: .now() + 0.75) {
                            sink(.success(()))
                        }
                    }

                    // Trigger the change only after a delay to account for animation
                    return subject
                        .zip(timerFuture)
                        .map(\.0)
                        .eraseToAnyPublisher()
                }

            case .removePreviewAndUnscheduleNotification(let pass):
                return Effect { context -> AnyPublisher<DispatchedAction<AppAction>, Never> in
                    let subject = PassthroughSubject<DispatchedAction<AppAction>, Never>()

                    DispatchQueue.global().async {
                        do {
                            let imageURL = pass.attachmentImageURL(extension: "png")
                            try FileManager.default.removeItem(at: imageURL)
                            logger.info("Removed alarm attachment: \(imageURL)")
                        } catch {
                            logger.warning("Failed to remove alarm attachment: \(error.localizedDescription)")
                        }
                        subject.send(
                            DispatchedAction<AppAction>(
                                .notification(
                                    .cancelNotifications(
                                        ids: [pass.notificationIdentifier]
                                    )
                                )
                            )
                        )
                        subject.send(completion: .finished)
                    }

                    // Make sure that the request finishes at least 0.75 seconds after triggering,
                    // leaving enough time for the animation to complete
                    let timerFuture = Future<Void, Never> { sink in
                        DispatchQueue.global().asyncAfter(deadline: .now() + 0.75) {
                            sink(.success(()))
                        }
                    }

                    return subject
                        .zip(timerFuture)
                        .map(\.0)
                        .eraseToAnyPublisher()
                }

            case let .scheduleNotification(passNotification):
                return Effect { context -> AnyPublisher<DispatchedAction<AppAction>, Never> in
                    let subject = PassthroughSubject<DispatchedAction<AppAction>, Never>()
                    let julianDate = context.dependencies.dateProvider().julianDate + getState().debugMenu.effectiveOffset
                    let julianDateDiff = (passNotification.alertJulianDate - julianDate) * TimeConstants.day2sec
                    let timeInterval = getState().debugMenu.rapidNotificationDelivery ? 10 : julianDateDiff
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
                            logger.error("Failed to schedule local notification for \(passNotification.pass.noradIndex) at \(Date(julianDate: passNotification.pass.rise.julianDate)): \(error.localizedDescription)")
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
                return .fireAndForget { _ in
                    let notificationCenter = UNUserNotificationCenter.current()

                    notificationCenter.removePendingNotificationRequests(withIdentifiers: Array(ids))
                }
                
            case .registerNotifications:
                return .fireAndForget { _ in
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
                        let julianDate = context.dependencies.dateProvider().julianDate + getState().debugMenu.effectiveOffset

                        switch satelliteCategory {
                        case .iss, .tianhe:
                            subject.send(
                                DispatchedAction(
                                    .satelliteOverview(
                                        .selectSatelliteOfSpecialInterest(
                                            .init(noradIndex: noradIndex),
                                            julianDateRange: JulianDateUtil.createJulianDateRange(now: julianDate),
                                            observer: observer
                                        )
                                    ),
                                    dispatcher: dispatcher
                                )
                            )
                        default:
                            subject.send(
                                DispatchedAction(
                                    .elementsLoader(
                                        .loadElements(
                                            category: satelliteCategory,
                                            fetchStrategy: .localWithin(21600 /* 6 hours */),
                                            selectNoradIndex: SelectNoradIndexParam(
                                                noradIndex: noradIndex,
                                                dateRange: JulianDateUtil.createJulianDateRange(now: julianDate),
                                                observer: observer
                                            ),
                                            calculatePass: ElementsLoaderCalculatePassParam(
                                                noradIndex: noradIndex,
                                                dateRange: JulianDateUtil.createJulianDateRange(now: julianDate),
                                                observer: observer
                                            )
                                        )
                                    ),
                                    dispatcher: dispatcher
                                )
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
