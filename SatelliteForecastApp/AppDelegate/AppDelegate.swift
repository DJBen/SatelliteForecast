//
//  AppDelegate.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/17/21.
//

import Foundation
import os
import UIKit
import UserNotifications
@preconcurrency import CombineRex
import SwiftUI
@preconcurrency import SatelliteKit
import SatelliteForecast
import SatelliteForecastImpl
import AppDelegate
import AppDelegateImpl

fileprivate let logger = Logger(subsystem: "io.djben.appDelegate", category: "class")

public class AppDelegate: NSObject, UIApplicationDelegate, AppDelegateActionDispatcher {
    public var dispatch: ((Store.ActionType) -> Void)?
    
    private lazy var implementation: AppDelegateImplementation = {
        let firebaseImpl = FirebaseAppDelegate()
        return StoreAwareAppDelegate(implementation: firebaseImpl, actionDispatcher: self)
    }()
    
    public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Solves the issue that preview is broken by Firebase
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            return true
        }
        
        // Set up notification delegates
        UNUserNotificationCenter.current().delegate = implementation as? UNUserNotificationCenterDelegate
        
        return implementation.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    public func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        implementation.application(application, didReceiveRemoteNotification: userInfo, fetchCompletionHandler: completionHandler)
    }
    
    public func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        implementation.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
    }
    
    public func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        implementation.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    }
    
    // MARK: - AppDelegateActionDispatcher
    
    public func dispatch(_ action: AppDelegateAction) {
        dispatch?(.appDelegate(action))
    }
    
    public func dispatchNotificationAction(_ action: NotificationAction) {
        dispatch?(.notification(action))
    }
}
