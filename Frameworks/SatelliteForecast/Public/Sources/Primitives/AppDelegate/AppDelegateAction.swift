//
//  AppDelegateAction.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 11/20/22.
//

import Foundation
import SwiftUI

public enum AppDelegateAction {
    case didRegisterForRemoteNotificationsWithDeviceToken(Data)
    case didReceiveFCMToken(String)
    case didFinishLaunchingWithOptions([UIApplication.LaunchOptionsKey : Any]? = nil)
    
    case scenePhaseDidChange(ScenePhase, ScenePhase)
}
