//
//  SatelliteForcastApp.swift
//  Shared
//
//  Created by Ben Lu on 5/28/21.
//

import SwiftUI
import SatelliteKit
import SatelliteForcastCore
import SwiftRex
import CombineRex
import CombineRextensions

@main
struct SatelliteForcastApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @StateObject var store = Store.shared.asObservableViewModel(initialState: .empty)

    var body: some Scene {
        WindowGroup {
            ViewProducer
                .satelliteElevationGraph(viewModel: store)
                .view()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {

    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        return true
    }
}
