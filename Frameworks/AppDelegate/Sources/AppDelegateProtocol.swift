//
//  AppDelegateProtocol.swift
//  AppDelegate
//
//  Created by Ben Lu on 7/27/25.
//

import Foundation
import UIKit
import UserNotifications
import SatelliteKit

/// Protocol defining the interface for app delegate functionality
public protocol AppDelegateProtocol: AnyObject {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]?) -> Bool
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void)
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error)
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data)
}

/// Protocol for handling Firebase Cloud Messaging
public protocol MessagingHandlerProtocol: AnyObject {
    func didReceiveRegistrationToken(_ fcmToken: String?)
}

/// Protocol for handling user notifications
public protocol NotificationHandlerProtocol: AnyObject {
    func willPresent(notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void)
    func didReceive(response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void)
}
