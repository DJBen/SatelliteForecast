//
//  AppDelegate.swift
//  SatelliteForcast (iOS)
//
//  Created by Ben Lu on 6/17/21.
//

import Foundation
import CombineRex

enum AppDelegateAction {
    case didRegisterForRemoteNotificationsWithDeviceToken(Data)
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Store.shared.dispatch(.appDelegate(.didRegisterForRemoteNotificationsWithDeviceToken(deviceToken)))
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        return true
    }
}
