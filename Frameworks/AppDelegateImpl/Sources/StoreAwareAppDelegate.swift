//
//  StoreAwareAppDelegate.swift
//  AppDelegateImpl
//
//  Created by Ben Lu on 7/27/25.
//

import Foundation
import UIKit
import UserNotifications
import AppDelegate
import SatelliteForecast
import SatelliteForecastImpl
import SatelliteKit
import FirebaseMessaging

/// Protocol for dispatching app delegate actions to a store
public protocol AppDelegateActionDispatcher: AnyObject {
    func dispatch(_ action: AppDelegateAction)
    func dispatchNotificationAction(_ action: NotificationAction)
}

/// Wrapper that connects the Firebase app delegate to the store
public class StoreAwareAppDelegate: NSObject, AppDelegateImplementation {
    private let implementation: AppDelegateImplementation
    private let actionDispatcher: AppDelegateActionDispatcher
    
    public init(implementation: AppDelegateImplementation, actionDispatcher: AppDelegateActionDispatcher) {
        self.implementation = implementation
        self.actionDispatcher = actionDispatcher
        super.init()
    }
    
    // MARK: - AppDelegateProtocol
    
    public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]?) -> Bool {
        let result = implementation.application(application, didFinishLaunchingWithOptions: launchOptions)
        actionDispatcher.dispatch(.didFinishLaunchingWithOptions(launchOptions))
        return result
    }
    
    public func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        implementation.application(application, didReceiveRemoteNotification: userInfo, fetchCompletionHandler: completionHandler)
    }
    
    public func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        implementation.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
    }
    
    public func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        implementation.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
        actionDispatcher.dispatch(.didRegisterForRemoteNotificationsWithDeviceToken(deviceToken))
    }
    
    // MARK: - MessagingHandlerProtocol
    
    public func didReceiveRegistrationToken(_ fcmToken: String?) {
        implementation.didReceiveRegistrationToken(fcmToken)
        if let fcmToken = fcmToken {
            actionDispatcher.dispatch(.didReceiveFCMToken(fcmToken))
        }
    }
    
    // MARK: - NotificationHandlerProtocol
    
    public func willPresent(notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        implementation.willPresent(notification: notification, withCompletionHandler: completionHandler)
    }
    
    public func didReceive(response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle deep link logic here
        let categoryIdentifier = response.notification.request.content.categoryIdentifier
        
        switch categoryIdentifier {
        case "PASS":
            switch response.actionIdentifier {
            case UNNotificationDismissActionIdentifier:
                break
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
                
                actionDispatcher.dispatchNotificationAction(
                    .deepLink(
                        category: satelliteCategory,
                        noradIndex: noradIndex,
                        observer: observer,
                        passIdentifier: response.notification.request.identifier
                    )
                )
            default:
                break
            }
        default:
            break
        }
        
        implementation.didReceive(response: response, withCompletionHandler: completionHandler)
    }
}

// MARK: - MessagingDelegate & UNUserNotificationCenterDelegate

extension StoreAwareAppDelegate: MessagingDelegate {
    public func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        didReceiveRegistrationToken(fcmToken)
    }
}

extension StoreAwareAppDelegate: UNUserNotificationCenterDelegate {
    public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        willPresent(notification: notification, withCompletionHandler: completionHandler)
    }
    
    public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        didReceive(response: response, withCompletionHandler: completionHandler)
    }
}
