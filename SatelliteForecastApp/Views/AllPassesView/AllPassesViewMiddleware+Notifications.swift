//
//  AllPassesViewMiddleware+Notifications.swift
//  SatelliteForecastApp
//
//  Created by Ben Lu on 4/4/22.
//

import Combine
import CombineRex
import os
import StarryNight
import SatelliteForecast
import SatelliteForecastImpl

fileprivate let logger = Logger(subsystem: "io.djben.allPassesView", category: "middleware")

extension EffectMiddleware where InputActionType == AllPassesViewAction, OutputActionType == NotificationAction, StateType == Void, Dependencies == Void {
    static var allPassesViewToNotification: EffectMiddleware<AllPassesViewAction, NotificationAction, Void, Void> {
        EffectMiddleware<AllPassesViewAction, NotificationAction, Void, Void>.onAction { (action, _, getState) -> Effect<Void, NotificationAction> in
            switch action {
            case .calculatePasses(_):
                return .doNothing
            case .recalculatePasses(_):
                return .doNothing
            case .selectPass(_):
                return .doNothing
            case .scheduleNotification(let passNotification, let passSnapshots):
                return Effect { context -> AnyPublisher<DispatchedAction<NotificationAction>, Never> in
                    let subject = PassthroughSubject<DispatchedAction<NotificationAction>, Never>()
                    let pass = passNotification.pass

                    DispatchQueue.global(qos: .userInitiated).async {
                        // Force dark theme
                        let traitCollection = UITraitCollection(userInterfaceStyle: .dark)
                        traitCollection.performAsCurrent {
                            let rect = CGRect(x: 0, y: 0, width: 350, height: 350)
                            let imageRect = rect.insetBy(dx: 5, dy: 5)
                            let renderer = UIGraphicsImageRenderer(size: rect.size)
                            let image = renderer.image { ctx in
                                SkyChart.addRasterizedBackgroundSkyPath(
                                    to: ctx,
                                    params: BackgroundSkyRenderParams(
                                        rect: imageRect,
                                        stars: Star.magitudeLessThan(4),
                                        constellations: Constellation.all,
                                        observer: passNotification.observer,
                                        julianDate: pass.rise.julianDate,
                                        starColor: UIColor(named: "star")!,
                                        constellationLineColor: UIColor(named: "constellationLine")!,
                                        drawPlanaryBodies: true,
                                        backgroundFillColor: UIColor.secondarySystemBackground,
                                        border: BackgroundSkyRenderParams.Border(borderColor: UIColor(named: "skyChartStroke")!),
                                        magToRadius: { CGFloat(3 * exp(-0.425 * $0)) }
                                    )
                                )

                                SkyChart.addRasterizedSatellitePassPath(
                                    to: ctx,
                                    params: SatellitePassPathRenderParams(
                                        rect: imageRect,
                                        snapshotsDuringPass: passSnapshots.snapshots,
                                        illuminatedColor: UIColor(named: "satellitePath_illuminated")!,
                                        unlitColor: UIColor(named: "satellitePath_notIlluminated")!
                                    )
                                )
                            }

                            do {
                                let imageURL = pass.attachmentImageURL(extension: "png")

                                guard let data = image.pngData() else {
                                    subject.send(
                                        DispatchedAction(
                                            .requestNotificationAuthorization(
                                                pendingNotification: passNotification
                                            )
                                        )
                                    )
                                    subject.send(completion: .finished)
                                    return
                                }

                                try data.write(to: imageURL)
                                logger.info("Generated alarm attachment \(imageURL)")

                                subject.send(DispatchedAction(.requestNotificationAuthorization(pendingNotification: passNotification)))
                                subject.send(completion: .finished)

                            } catch {
                                logger.error("Failed to save alarm attachment: \(error.localizedDescription)")
                                subject.send(DispatchedAction(.requestNotificationAuthorization(pendingNotification: passNotification)))
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
            case .unscheduleNotification(let pass):
                return Effect { context -> AnyPublisher<DispatchedAction<NotificationAction>, Never> in
                    let subject = PassthroughSubject<DispatchedAction<NotificationAction>, Never>()

                    DispatchQueue.global().async {
                        do {
                            let imageURL = pass.attachmentImageURL(extension: "png")
                            try FileManager.default.removeItem(at: imageURL)
                            logger.info("Removed alarm attachment: \(imageURL)")
                        } catch {
                            logger.warning("Failed to remove alarm attachment: \(error.localizedDescription)")
                        }
                        subject.send(
                            DispatchedAction<NotificationAction>(
                                .cancelNotifications(
                                    ids: [pass.notificationIdentifier]
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

            }
        }
    }
}

extension EffectMiddleware where InputActionType == AllPassesViewAction, OutputActionType == NotificationAction, StateType == Void, Dependencies == Void {
    func lift() -> AnyMiddleware<AppAction, AppAction, AppState> {
        lift(
            inputAction: \.allPassesView,
            outputAction: AppAction.notification,
            state: { _ in }
        )
        .eraseToAnyMiddleware()
    }
}
