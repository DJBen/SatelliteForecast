//
//  AppDelegateReducer.swift
//  SatelliteForecastPackage
//
//  Created by Sihao Lu on 6/14/25.
//

import Foundation
import os
@preconcurrency import SwiftRex
import SatelliteForecast

fileprivate let logger = Logger(subsystem: "io.djben.appDelegate", category: "reducer")

extension Reducer where ActionType == AppDelegateAction, StateType == AppState {
    public static let appDelegateReducer = Reducer.reduce { action, state in
        switch action {
        case .didReceiveFCMToken(let fcmToken):
            state.fcmToken = fcmToken
        case .didRegisterForRemoteNotificationsWithDeviceToken(let deviceToken):
            state.deviceToken = deviceToken
        default:
            break
        }
    }
}
