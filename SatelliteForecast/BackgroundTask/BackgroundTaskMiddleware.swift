//
//  BackgroundTaskMiddleware.swift
//  BackgroundTaskMiddleware
//
//  Created by Ben Lu on 8/19/21.
//

import BackgroundTasks
import Combine
import CombineRex
import Foundation
import os

fileprivate let logger = Logger(subsystem: "io.djben.backgroundTasks", category: "middleware")

fileprivate let calculateUpcomingPassesTaskID = "io.djben.SatelliteForecast.backgroundTasks.calculateUpcomingPasses"

enum BackgroundTask {
    case registerHandleCalculatingUpcomingPasses
    case submitHandleCalculatingUpcomingPasses
    
    static func handleCalculatingUpcomingPasses(task: BGTask) {
        logger.info("Task \(task.identifier) handled at \(Date())")
        task.setTaskCompleted(success: true)
    }
}

extension EffectMiddleware where
    InputActionType == BackgroundTask,
    OutputActionType == AppAction,
    StateType == AppState,
    Dependencies == Void {

    static var backgroundTask: EffectMiddleware<BackgroundTask, AppAction, AppState, Void> {
        EffectMiddleware<BackgroundTask, AppAction, AppState, Void>.onAction { action, _, getState in
            switch action {
            case .registerHandleCalculatingUpcomingPasses:
                return .fireAndForget {
                    BGTaskScheduler.shared.register(
                        forTaskWithIdentifier: calculateUpcomingPassesTaskID,
                        using: nil,
                        launchHandler: BackgroundTask.handleCalculatingUpcomingPasses(task:)
                    )
                }
            case .submitHandleCalculatingUpcomingPasses:
                return .fireAndForget {
                    let request = BGProcessingTaskRequest(identifier: calculateUpcomingPassesTaskID)
                    // Calculation of passes is power intensive
                    request.requiresExternalPower = true
                    request.earliestBeginDate = Date(timeIntervalSinceNow: 0)
                    
                    do {
                        try BGTaskScheduler.shared.submit(request)
                    } catch {
                        logger.warning("Unable to schedule background tasks: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    func lift() -> AnyMiddleware<AppAction, AppAction, AppState> {
        return lift(
            inputAction: \.backgroundTask
        )
        .eraseToAnyMiddleware()
    }
}
