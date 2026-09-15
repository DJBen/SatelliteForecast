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
import SwiftUI
@preconcurrency import SatelliteKit
import SatelliteForecast
import SatelliteForecastImpl
import AppDelegate
import AppDelegateImpl

fileprivate let logger = Logger(subsystem: "io.djben.appDelegate", category: "class")

public class AppDelegate: NSObject, UIApplicationDelegate, AppDelegateActionDispatcher {
    public var onLifecycle: ((AppDelegateAction) -> Void)? {
        didSet { if let onLifecycle { let events = pendingLifecycle; pendingLifecycle = []; events.forEach(onLifecycle) } }
    }
    public var onDeepLink: ((SatelliteCategory, UInt, LatLonAlt) -> Void)? {
        didSet { if let onDeepLink { let links = pendingLinks; pendingLinks = []; links.forEach { onDeepLink($0.0, $0.1, $0.2) } } }
    }
    private var pendingLifecycle: [AppDelegateAction] = []
    private var pendingLinks: [(SatelliteCategory, UInt, LatLonAlt)] = []

    private lazy var implementation: AppDelegateImpl = {
        return AppDelegateImpl(actionDispatcher: self)
    }()
    
    public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Keep Firebase initialization out of the snapshot test host.
        if ProcessInfo.processInfo.environment["SATELLITE_SNAPSHOT_TESTS"] == "1" {
            return true
        }
        
        // Set up notification delegates
        UNUserNotificationCenter.current().delegate = implementation
        
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
        if let onLifecycle { onLifecycle(action) } else { pendingLifecycle.append(action) }
    }
    
    public func dispatchNotificationAction(_ action: NotificationAction) {
        if case .deepLink(let category, let id, let observer, _) = action {
            if let onDeepLink { onDeepLink(category, id, observer) }
            else { pendingLinks.append((category, id, observer)) }
        }
    }
}
