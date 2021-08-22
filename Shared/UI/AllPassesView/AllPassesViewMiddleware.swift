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
                case .recalculatePasses:
                    return .sequence([
                        .tlePropagator(.purgePassesAndSnapshots),
                        .allPassesView(.calculatePasses)
                    ])
                case .calculatePasses:
                    return Effect { context -> AnyPublisher<DispatchedAction<AppAction>, Never> in
                        let state = getState()

                        // Precondition: TLE must be ready
                        guard let noradIndex = state.navigationState.selectedSatelliteNoradIndex, let info = state.satelliteLoaderState[noradIndex] else {
                            logger.fault("TLE not ready for the selected satellite when calculating passes")
                            return Empty().eraseToAnyPublisher()
                        }

                        // Precondition: An observer coordinate must exist
                        // Freeze the coordinate during the pass viewing workflow, so the coordinate
                        // stays the same.
                        guard let observer = state.locationState.location.map(LatLonAlt.init) else {
                           logger.info("Will not generate satellite \(noradIndex) ephemerides: lack of core location coordinate")
                            return Empty().eraseToAnyPublisher()
                        }

                        guard let julianDateRange = state.julianDateRange else {
                            logger.warning("Will not generate satellite \(noradIndex) ephemerides: missing julian date range")
                            return Empty().eraseToAnyPublisher()
                        }

                        // Loads satellite passes
                        let subject = PassthroughSubject<DispatchedAction<AppAction>, Never>()

                        DispatchQueue.global(qos: .userInitiated).async {
                            let passes: [Pass]
                            let fineSnapshots: BTree<Double, SatelliteSnapshot>

                            // Use cached satellite ephemerides if calculated within the last hour.
                            if let satelliteState = state.selectedSatelliteTrails,
                               julianDateRange.lowerBound - satelliteState.snapshots.first!.1.julianDate < TimeConstants.hrs2day,
                               let existingPasses = satelliteState.passes {
                                passes = existingPasses
                                fineSnapshots = satelliteState.snapshots
                                logger.debug("Ephemeride of \(noradIndex) are already generated. Skipping.")
                            } else {
                                let satellite = info.satellite
                                logger.debug("Calculating pass within date range \(julianDateRange) for \(String(describing: observer)) at interval of 30s")

                                let snapshots = satellite
                                    .snapshots(
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

                                (passes, fineSnapshots) = satellite
                                    .findPasses(
                                        noradIndex: Int(satellite.noradIdent)!,
                                        observer: observer,
                                        coarseSnapshots: snapshots
                                    )

                                subject.send(
                                    DispatchedAction<AppAction>(
                                        .tlePropagator(
                                            .foundPasses(
                                                passes,
                                                fineSnapshots: fineSnapshots,
                                                noradIndex: noradIndex,
                                                observer: observer
                                            )
                                        )
                                    )
                                )
                                logger.debug("Generated emphemerides and passes of \(noradIndex).")
                            }

                            subject.send(completion: .finished)
                        }
                        return subject
                            .eraseToAnyPublisher()
                    }

                case .selectPass:
                    return .doNothing
                    
                case let .scheduleNotification(passNotification):
                    return Effect { context -> AnyPublisher<DispatchedAction<AppAction>, Never> in
                        let subject = PassthroughSubject<DispatchedAction<AppAction>, Never>()
                        let state = getState()
                        let pass = passNotification.pass
                        guard let snapshots = state.satelliteTrails[pass.noradIndex]?.snapshots else {
//                            logger.debug("\(pass.noradIndex)'s pass \(pass.rise.julianDate)->\(pass.set.julianDate) lacks snapshots: rasterization on hold")
                            subject.send(DispatchedAction(.notification(.requestNotificationAuthorization(pendingNotification: passNotification))))
                            subject.send(completion: .finished)
                            return subject.eraseToAnyPublisher()
                        }
                        
                        DispatchQueue.global(qos: .userInitiated).async {
                            let snapshotsDuringPass = snapshots.subtree(from: pass.rise.julianDate, through: pass.set.julianDate)
                            
                            let rect = CGRect(x: 0, y: 0, width: 500, height: 500)
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
                                        starColor: UIColor.black,
                                        constellationLineColor: UIColor.lightGray.withAlphaComponent(0.4),
                                        drawPlanaryBodies: true,
                                        border: BackgroundSkyRenderParams.Border(borderColor: UIColor(named: "skyChartStroke")!),
                                        magToRadius: { CGFloat(3 * exp(-0.425 * $0)) }
                                    )
                                )
                                
                                SkyChart.addRasterizedSatellitePassPath(
                                    to: ctx,
                                    params: SatellitePassPathRenderParams(
                                        rect: imageRect,
                                        snapshotsDuringPass: snapshotsDuringPass,
                                        illuminatedColor: UIColor.black,
                                        unlitColor: UIColor.lightGray
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
