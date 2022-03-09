//
//  AppDelegate.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/17/21.
//

import Foundation
import os
import CombineRex
import SwiftUI
import SatelliteKit

fileprivate let logger = Logger(subsystem: "io.djben.appDelegate", category: "class")

enum AppDelegateAction {
    case didRegisterForRemoteNotificationsWithDeviceToken(Data)
    case didFinishLaunchingWithOptions([UIApplication.LaunchOptionsKey : Any]? = nil)
    
    case scenePhaseDidChange(ScenePhase)
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Store.shared.dispatch(.appDelegate(.didRegisterForRemoteNotificationsWithDeviceToken(deviceToken)))
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        Store.shared.dispatch(.appDelegate(.didFinishLaunchingWithOptions(launchOptions)))
        UNUserNotificationCenter.current().delegate = self
        return true
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // TODO: hide when the information is currently visible to the user
        completionHandler([.banner, .list])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let categoryIdentifier = response.notification.request.content.categoryIdentifier
        
        switch categoryIdentifier {
        case "PASS":
            switch response.actionIdentifier {
            case UNNotificationDismissActionIdentifier:
                completionHandler()
            case UNNotificationDefaultActionIdentifier:
                let userInfo = response.notification.request.content.userInfo
                guard let noradIndex = userInfo["noradIndex"] as? UInt,
                      let observer = (userInfo["observer"] as? Data).flatMap({ try? JSONDecoder().decode(LatLonAlt.self, from: $0) }) else {
                    break
                }
                
                let satelliteCategory = (userInfo["satelliteCategory"] as? Data).flatMap {
                    try? JSONDecoder().decode(SatelliteCategory?.self, from: $0)
                }

                Store.shared.dispatch(
                    .notification(.deepLink(
                        category: satelliteCategory,
                        noradIndex: noradIndex,
                        observer: observer,
                        passIdentifier: response.notification.request.identifier
                    ))
                )

                completionHandler()
            default:
                completionHandler()
            }
        default:
            logger.warning("Unknown push notification category \(categoryIdentifier). Ignored.")
        }
    }
}
