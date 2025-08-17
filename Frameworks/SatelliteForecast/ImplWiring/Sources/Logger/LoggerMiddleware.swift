//
//  LoggerMiddleware.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 2/10/22.
//

import Combine
@preconcurrency import CombineRex
import SatelliteForecastImpl
import AppDelegate
import SatelliteForecast
import CustomDump
import BTreeCustomDump

extension EffectMiddleware where InputActionType == AppAction, OutputActionType == AppAction, StateType == AppState, Dependencies == Void {
    public static var loggerMiddleware: EffectMiddleware<AppAction, AppAction, AppState, Void> {
        #if DEBUG
        EffectMiddleware.onAction { action, _, getState in
            return .fireAndForget {
                switch action {
                case .initializeAllConstellations(_):
                    customDump(action, maxDepth: 1)
                case .appDelegate(let appDelegateAction):
                    customDump(appDelegateAction)
                case .backgroundTask(let backgroundTask):
                    customDump(backgroundTask)
                case .notification(let notificationAction):
                    customDump(notificationAction, maxDepth: 2)
                case .location(let locationAction):
                    customDump(locationAction)
                case .locationOutput(let locationOutput):
                    customDump(locationOutput)
                case .elementsLoader(let elementsLoaderAction):
                    customDump(elementsLoaderAction)
                case .elementsLoaderOutput(let elementsLoaderOutput):
                    customDump(elementsLoaderOutput, maxDepth: 1)
                case .rootView(let rootViewAction):
                    customDump(rootViewAction)
                case .satelliteOverview(let satelliteOverviewViewAction):
                    customDump(satelliteOverviewViewAction)
                case .satelliteCategory(let satelliteCateogryViewAction):
                    customDump(satelliteCateogryViewAction)
                case .satelliteListView(let satelliteListViewAction):
                    customDump(satelliteListViewAction)
                case .satelliteListOutput(let satelliteListViewOutput):
                    customDump(satelliteListViewOutput, maxDepth: 2)
                case .settingsOverview(let settingsOverviewAction):
                    customDump(settingsOverviewAction)
                case .singleSatelliteWrappingView(let singleSatelliteWrappingViewAction):
                    customDump(singleSatelliteWrappingViewAction)
                case .allPassesView(let allPassesViewAction):
                    customDump(allPassesViewAction, maxDepth: 2)
                case .passView(let passViewAction):
                    customDump(passViewAction, maxDepth: 2)
                case .satelliteElevationGraph(let satelliteElevationGraphAction):
                    customDump(satelliteElevationGraphAction)
                case .skyChart(_):
                    // Do nothing
                    break
                case .skyChartOutput(_):
                    // Do nothing
                    break
                case .backgroundSky(_):
                    // Do nothing
                    break
                case .backgroundSkyOutput(let backgroundSkyOutput):
                    switch backgroundSkyOutput {
                    case .rasterizedBackgroundSky(_, let quality, let julianDate, key: _):
                        customDump("rasterizedBackgroundSky(quality: \(quality), julianDate: \(julianDate))")
                    }
                case .elementsPropagator(let elementsPropagatorAction):
                    customDump(elementsPropagatorAction)
                case .elementsPropagatorOutput(let elementsPropagatorOutput):
                    switch elementsPropagatorOutput {
                    case .foundPassesAndSnapshots(let passSnapshotList, let noradIndex, let observer):
                        customDump("foundPassesAndSnapshots(passes: \(passSnapshotList.count), noradIndex: \(noradIndex), observer: \(observer))")
                    case .propagatedSnapshots(let snapshots, let noradIndex, let observer):
                        customDump("propagatedSnapshots(snapshots: \(snapshots.count), noradIndex: \(noradIndex), observer: \(observer))")
                    }
                case .debugMenu(let debugMenuAction):
                    customDump(debugMenuAction)
                case .alarmSettingsCell(let alarmSettingsCellAction):
                    customDump(alarmSettingsCellAction)
                case .alarmSettingsView(let alarmSettingsViewAction):
                    customDump(alarmSettingsViewAction)
                case .passAlarmSettings(let passAlarmSettingsModalViewAction):
                    customDump(passAlarmSettingsModalViewAction, maxDepth: 2)
                case .realtimeSky(let realtimeSkyViewAction):
                    switch realtimeSkyViewAction {
                    case .propagateCurrentEphemerides(_, observer: _, julianDate: _):
                        break
//                    case .propagateCurrentEphemerides(let elements, let observer, let julianDate):
//                         customDump("propagateCurrentEphemerides(elements.count: \(elements.count), observer: \(observer), julianDate: \(julianDate))")
                    case .setRealtimeSkyViewActive(_):
                        customDump(realtimeSkyViewAction)
                    case .loadElements:
                        customDump(realtimeSkyViewAction)
                    case .purgeElements:
                        customDump(realtimeSkyViewAction)
                    }
                case .realtimeSkyOutput(let realtimeSkyViewOutput):
                    customDump(realtimeSkyViewOutput, maxDepth: 1)
                case .detailedPassView(let detailedPassAction):
                    customDump(detailedPassAction)
                case .onboarding(let onboardingAction):
                    customDump(onboardingAction)
                }
            }
        }
        #else
        EffectMiddleware.onAction { _, _, _ in
            return .doNothing
        }
        #endif
    }
}
