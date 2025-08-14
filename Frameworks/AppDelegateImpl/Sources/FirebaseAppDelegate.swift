//
//  FirebaseAppDelegate.swift
//  AppDelegateImpl
//
//  Created by Ben Lu on 7/27/25.
//

import Foundation
import os
import UIKit
import UserNotifications
import AppDelegate
import SatelliteKit
import SatelliteForecast
import FirebaseCore
import FirebaseMessaging
import FirebaseFirestore

fileprivate let logger = Logger(subsystem: "io.djben.appDelegate", category: "firebase")
fileprivate let gcmMessageIDKey = "gcm.message_id"

/// Firebase-based implementation of AppDelegateImplementation
public class FirebaseAppDelegate: NSObject, AppDelegateImplementation {
    
    public override init() {
        super.init()
    }
    
    // MARK: - AppDelegateProtocol
    
    public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]?) -> Bool {
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
        
        return true
    }
    
    public func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if let messageID = userInfo[gcmMessageIDKey] {
            print("Message ID: \(messageID)")
        }
        print(userInfo)
        completionHandler(.noData)
    }
    
    public func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Unable to register for remote notifications: \(error.localizedDescription)")
    }
    
    public func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("APNs token retrieved: \(deviceToken)")
    }
    
    // MARK: - MessagingHandlerProtocol
    
    public func didReceiveRegistrationToken(_ fcmToken: String?) {
        print("Firebase registration token: \(String(describing: fcmToken))")
        guard let fcmToken else {
            return
        }
    }
    
    // MARK: - NotificationHandlerProtocol
    
    public func willPresent(notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // TODO: hide when the information is currently visible to the user
        completionHandler([.banner, .list])
    }
    
    public func didReceive(response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let categoryIdentifier = response.notification.request.content.categoryIdentifier
        
        switch categoryIdentifier {
        case "PASS":
            switch response.actionIdentifier {
            case UNNotificationDismissActionIdentifier:
                completionHandler()
            case UNNotificationDefaultActionIdentifier:
                let userInfo = response.notification.request.content.userInfo
                guard let noradIndex = (userInfo["noradIndex"] as? String).flatMap(UInt.init),
                      let satelliteCategory = (userInfo["satelliteCategory"] as? String).flatMap(SatelliteCategory.init(rawValue:)) else {
                    break
                }
                
                let observer: LatLonAlt
                if let anObserver = (userInfo["observer"] as? Data).flatMap({ try? JSONDecoder().decode(LatLonAlt.self, from: $0) }) {
                    observer = anObserver
                } else if let lat = (userInfo["lat"] as? String).flatMap(Double.init), let lon = (userInfo["lon"] as? String).flatMap(Double.init), let alt = (userInfo["alt"] as? String).flatMap(Double.init) {
                    observer = LatLonAlt(lat, lon, alt)
                } else {
                    break
                }

                completionHandler()
            default:
                completionHandler()
            }
        default:
            logger.warning("Unknown push notification category \(categoryIdentifier). Ignored.")
        }
    }
}

// MARK: - MessagingDelegate

extension FirebaseAppDelegate: MessagingDelegate {
    public func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        didReceiveRegistrationToken(fcmToken)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension FirebaseAppDelegate: UNUserNotificationCenterDelegate {
    public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        willPresent(notification: notification, withCompletionHandler: completionHandler)
    }
    
    public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        didReceive(response: response, withCompletionHandler: completionHandler)
    }
}
