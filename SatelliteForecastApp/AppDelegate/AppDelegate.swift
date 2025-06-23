//
//  AppDelegate.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/17/21.
//

import Foundation
import os
@preconcurrency import CombineRex
import SwiftUI
@preconcurrency import SatelliteKit
import SatelliteForecast
import FirebaseCore
import FirebaseMessaging
import FirebaseFirestore

fileprivate let logger = Logger(subsystem: "io.djben.appDelegate", category: "class")
fileprivate let gcmMessageIDKey = "gcm.message_id"

public class AppDelegate: NSObject, UIApplicationDelegate {
    public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        FirebaseApp.configure()
        Messaging.messaging().delegate = self
        // Initializes Firestore; creates shared instance once
        let _ = Firestore.firestore()
        
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
          options: authOptions,
          completionHandler: { _, _ in }
        )

        application.registerForRemoteNotifications()
        Store.shared.dispatch(.appDelegate(.didFinishLaunchingWithOptions(launchOptions)))
        return true
    }
    
    public func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if let messageID = userInfo[gcmMessageIDKey] {
            print("Message ID: \(messageID)")
        }
        print(userInfo)
    }
    
    public func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Unable to register for remote notifications: \(error.localizedDescription)")
    }
    
    public func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Store.shared.dispatch(.appDelegate(.didRegisterForRemoteNotificationsWithDeviceToken(deviceToken)))
        print("APNs token retrieved: \(deviceToken)")
    }
}

extension AppDelegate: MessagingDelegate {
    public func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("Firebase registration token: \(String(describing: fcmToken))")
        guard let fcmToken else {
            return
        }
        Store.shared.dispatch(.appDelegate(.didReceiveFCMToken(fcmToken)))
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // TODO: hide when the information is currently visible to the user
        completionHandler([.banner, .list])
    }
    
    public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
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
