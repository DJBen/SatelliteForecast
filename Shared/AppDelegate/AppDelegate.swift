//
//  AppDelegate.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/17/21.
//

import Foundation
import CombineRex
import SwiftUI

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
        switch response.actionIdentifier {
        case UNNotificationDismissActionIdentifier:
            completionHandler()
        case UNNotificationDefaultActionIdentifier:
            completionHandler()
        default:
            completionHandler()
        }
    }
}
