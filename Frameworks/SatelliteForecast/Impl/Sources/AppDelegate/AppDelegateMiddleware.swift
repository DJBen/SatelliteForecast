//
//  AppDelegateMiddleware.swift
//  AppDelegateMiddleware
//
//  Created by Ben Lu on 8/18/21.
//

import BackgroundTasks
import Foundation
import Combine
@preconcurrency import CombineRex
import Geohash
import os
@preconcurrency import SatelliteKit
import SatelliteForecast
import FirebaseFirestore
import UIKit

fileprivate let logger = Logger(subsystem: "io.djben.appDelegate", category: "middleware")

extension UIDevice {
    var machineName: String {
        var info = utsname()
        return withUnsafeMutablePointer(to: &info) { info in
            guard uname(info) == 0 else { return model }
            let offset = MemoryLayout.offset(of: \utsname.machine)!
            let machine = UnsafeRawPointer(info).advanced(by: offset).assumingMemoryBound(to: CChar.self)
            return String(cString: machine)
        }
    }
}

extension EffectMiddleware where
    InputActionType == AppDelegateAction,
    OutputActionType == AppAction,
    StateType == AppState,
    Dependencies == Void {

    public static var appDelegate: EffectMiddleware<AppDelegateAction, AppAction, AppState, Void> {
        EffectMiddleware<AppDelegateAction, AppAction, AppState, Void>
            .onAction { action, _, getState in
                switch action {
                case .didFinishLaunchingWithOptions(_):
                    return .sequence([
                        .backgroundTask(.registerHandleCalculatingUpcomingPasses),
                        .notification(.loadNotificationsFromPersistenceStorage),
                        .notification(.registerNotifications),
                    ])
                case .didRegisterForRemoteNotificationsWithDeviceToken(_):
                    return .doNothing
                case .didReceiveFCMToken(let fcmToken):
                    return .fireAndForget {
                        let appVariant: String
                        #if DEBUG
                        appVariant = "debug"
                        #else
                        appVariant = "release"
                        #endif
                    
                        let device = UIDevice.current
                        if appVariant == "debug" && device.machineName == "arm64" {
                            // Do not write to firebase for simulators
                            return
                        }
                        var data: [String: Any] = [
                            "deviceModel": device.machineName,
                            "osVersion": device.systemVersion,
                            "appVariant": appVariant,
                            "lastAppLaunch": Timestamp(date: Date()),
                            "tzOffset": TimeZone.current.secondsFromGMT(),
                            "locale": Locale.current.identifier
                        ]
                        if let location = getState().locationResources.currentLocation {
                            let geoHash = Geohash.encode(
                                latitude: location.coordinate.latitude,
                                longitude: location.coordinate.longitude,
                                length: 5 // ±2.4km precision
                            )
                            data.merge([
                                "lat": location.coordinate.latitude,
                                "lon": location.coordinate.longitude,
                                "alt": location.altitude,
                                "geoHash5": geoHash
                            ], uniquingKeysWith: { $1 })
                        }
                        let db = Firestore.firestore()
                        db.collection("users").document(fcmToken).setData(data, merge: true)
                    }
                case let .scenePhaseDidChange(phase):
                    switch phase {
                    case .active:
                        logger.debug("App becomes active")
                        
                        return .just(.notification(.loadNotificationsFromPersistenceStorage))
                    case .inactive:
                        logger.debug("App becomes inactive")
                        return .doNothing
                    case .background:
                        logger.debug("App enters background")

                        return .sequence([
                            .backgroundTask(.submitHandleCalculatingUpcomingPasses),
                            .notification(.saveNotificationsToPersistenceStorage(getState().notificationResources.scheduledPassNotifications))
                        ])
                    @unknown default:
                        return .doNothing
                    }
                }
            }
    }
}
