//
//  AllPassesViewMiddleware.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/7/21.
//

import BTree
import Foundation
import os
import Combine
import CombineRex
import SatelliteKit
import SatelliteForecastCore
import UserNotifications
import StarryNight

fileprivate let logger = Logger(subsystem: "io.djben.allPassesView", category: "middleware")

extension EffectMiddleware where
    InputActionType == AllPassesViewAction,
    OutputActionType == AppAction,
    StateType == AppState,
    Dependencies == Void {

    static var allPassesView: EffectMiddleware<AllPassesViewAction, AppAction, AppState, Void> {
        EffectMiddleware<AllPassesViewAction, AppAction, AppState, Void>
            .onAction { (action, _, getState) -> Effect<Void, AppAction> in
                switch action {
                case let .recalculatePasses(params):
                    return .sequence([
                        .tlePropagator(.purgePassesAndSnapshots),
                        .allPassesView(.calculatePasses(params))
                    ])
                case let .calculatePasses(params):
                    return Effect { context -> AnyPublisher<DispatchedAction<AppAction>, Never> in
                        let state = getState()
                        let (info, noradIndex, observer, julianDateRange) = (
                            params.satelliteInfo,
                            params.selectedNoradIndex,
                            params.observer,
                            params.julianDateRange
                        )

                        // Loads satellite passes
                        let subject = PassthroughSubject<DispatchedAction<AppAction>, Never>()

                        DispatchQueue.global(qos: .userInitiated).async {
                            // Use cached satellite ephemerides if calculated within the last hour.
                            if let satelliteState = state.satelliteTrails[noradIndex],
                               abs(julianDateRange.lowerBound - satelliteState.snapshots.first!.julianDate) < TimeConstants.hrs2day,
                               let _ = satelliteState.passSnapshots {
                                logger.debug("Ephemeride of \(noradIndex) are already generated. Skipping.")
                            } else {
                                logger.debug("Calculating pass within date range \(julianDateRange) for \(String(describing: observer)) at interval of 30s")

                                do {
                                    let snapshots = try info.generateSnapshots(
                                        observer: observer,
                                        julianDateRange: julianDateRange,
                                        interval: 30
                                    )

                                    subject.send(
                                        DispatchedAction<AppAction>(
                                            .tlePropagator(
                                                .propagatedSnapshots(
                                                    snapshots,
                                                    noradIndex: noradIndex,
                                                    observer: observer
                                                )
                                            )
                                        )
                                    )

                                    let passSnapshots = try info.findPasses(
                                        observer: observer,
                                        coarseSnapshots: snapshots,
                                        qsMag: info.qsMag,
                                        crossSectionArea: info.satCat?.rcs
                                    )

                                    subject.send(
                                        DispatchedAction<AppAction>(
                                            .tlePropagator(
                                                .foundPassesAndSnapshots(
                                                    passSnapshots,
                                                    noradIndex: noradIndex,
                                                    observer: observer
                                                )
                                            )
                                        )
                                    )
                                    logger.debug("Generated emphemerides and passes of \(noradIndex).")
                                } catch {
                                    print("Failed to propagate \(noradIndex): \(error)")
                                }
                            }

                            subject.send(completion: .finished)
                        }
                        return subject
                            .eraseToAnyPublisher()
                    }

                case .selectPass(_):
                    return .doNothing
                    
                case let .scheduleNotification(passNotification):
                    return Effect { context -> AnyPublisher<DispatchedAction<AppAction>, Never> in
                        let subject = PassthroughSubject<DispatchedAction<AppAction>, Never>()
                        let state = getState()
                        let pass = passNotification.pass
                        guard let passSnapshots = state.satelliteTrails[pass.noradIndex]?.passSnapshots?.first(where: { $0.pass == pass }) else {
//                            logger.debug("\(pass.noradIndex)'s pass \(pass.rise.julianDate)->\(pass.set.julianDate) lacks snapshots: rasterization on hold")
                            subject.send(DispatchedAction(.notification(.requestNotificationAuthorization(pendingNotification: passNotification))))
                            subject.send(completion: .finished)
                            return subject.eraseToAnyPublisher()
                        }
                        
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
                                        subject.send(DispatchedAction(.notification(.requestNotificationAuthorization(pendingNotification: passNotification))))
                                        subject.send(completion: .finished)
                                        return
                                    }
                                    
                                    try data.write(to: imageURL)
                                    logger.info("Generated alarm attachment \(imageURL)")
                                    
                                    subject.send(DispatchedAction(.notification(.requestNotificationAuthorization(pendingNotification: passNotification))))
                                    subject.send(completion: .finished)
                                    
                                } catch {
                                    logger.error("Failed to save alarm attachment: \(error.localizedDescription)")
                                    subject.send(DispatchedAction(.notification(.requestNotificationAuthorization(pendingNotification: passNotification))))
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
                        
                        return subject
                            .zip(timerFuture)
                            .map(\.0)
                            .eraseToAnyPublisher()
                    }
                                        
                case let .unscheduleNotification(pass):
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
                            subject.send(DispatchedAction<AppAction>(.notification(.cancelNotifications(ids: [pass.notificationIdentifier]))))
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
