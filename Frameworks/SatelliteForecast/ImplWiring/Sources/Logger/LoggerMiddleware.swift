//
//  LoggerMiddleware.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 2/10/22.
//

import Combine
import CombineRex

extension EffectMiddleware where InputActionType == AppAction, OutputActionType == AppAction, StateType == AppState, Dependencies == Void {
    public static var loggerMiddleware: EffectMiddleware<AppAction, AppAction, AppState, Void> {
        EffectMiddleware.onAction { action, _, getState in
            return .fireAndForget {
                switch action {
                case .appDelegate(let appDelegateAction):
                    print(appDelegateAction)
                case .backgroundTask(let backgroundTask):
                    print(backgroundTask)
                case .notification(let notificationAction):
                    print(notificationAction)
                case .location(let locationAction):
                    print(locationAction)
                case .locationOutput(let locationOutput):
                    print(locationOutput)
                case .elementsLoader(let elementsLoaderAction):
                    print(elementsLoaderAction)
                case .elementsLoaderOutput(let elementsLoaderOutput):
                    switch elementsLoaderOutput {
                    case .loadedSatelliteElements(let satelliteCategory, _, let selectSpecialNoradIndex, let selectNoradIndex, let calculatePass):
                        print("loadedSatelliteElements(\(satelliteCategory), selectSpecialNoradIndex: \(String(describing: selectSpecialNoradIndex)), selectNoradIndex: \(String(describing: selectNoradIndex)), calculatePass: \(calculatePass != nil))")
                    case .failedLoadingElements(_, _):
                        print(elementsLoaderOutput)
                    }
                case .rootView(let rootViewAction):
                    print(rootViewAction)
                case .satelliteOverview(let satelliteOverviewViewAction):
                    print(satelliteOverviewViewAction)
                case .satelliteListView(let satelliteListViewAction):
                    print(satelliteListViewAction)
                case .settingsOverview(let settingsOverviewAction):
                    print(settingsOverviewAction)
                case .singleSatelliteWrappingView(let singleSatelliteWrappingViewAction):
                    print(singleSatelliteWrappingViewAction)
                case .allPassesView(let allPassesViewAction):
                    print(allPassesViewAction)
                case .passView(let passViewAction):
                    print(passViewAction)
                case .satelliteElevationGraph(let satelliteElevationGraphAction):
                    print(satelliteElevationGraphAction)
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
                        print("rasterizedBackgroundSky(quality: \(quality), julianDate: \(julianDate))")
                    }
                case .elementsPropagator(let elementsPropagatorAction):
                    print(elementsPropagatorAction)
                case .elementsPropagatorOutput(let elementsPropagatorOutput):
                    switch elementsPropagatorOutput {
                    case .foundPassesAndSnapshots(let passSnapshotList, let noradIndex, let observer):
                        print("foundPassesAndSnapshots(passes: \(passSnapshotList.count), noradIndex: \(noradIndex), observer: \(observer))")
                    case .propagatedSnapshots(let snapshots, let noradIndex, let observer):
                        print("propagatedSnapshots(snapshots: \(snapshots.count), noradIndex: \(noradIndex), observer: \(observer))")
                    }
                case .debugMenu(let debugMenuAction):
                    print(debugMenuAction)
                case .observerCell(let observerCellAction):
                    print(observerCellAction)
                case .alarmSettingsCell(let alarmSettingsCellAction):
                    print(alarmSettingsCellAction)
                case .alarmSettingsView(let alarmSettingsViewAction):
                    print(alarmSettingsViewAction)
                case .passAlarmSettings(let passAlarmSettingsModalViewAction):
                    print(passAlarmSettingsModalViewAction)
                case .realtimeSky(let realtimeSkyViewAction):
                    switch realtimeSkyViewAction {
                    case .propagateCurrentEphemerides(_, observer: _, julianDate: _):
                        break
//                    case .propagateCurrentEphemerides(let elements, let observer, let julianDate):
//                         print("propagateCurrentEphemerides(elements.count: \(elements.count), observer: \(observer), julianDate: \(julianDate))")
                    case .setRealtimeSkyViewActive(_):
                        print(realtimeSkyViewAction)
                    case .loadElements:
                        print(realtimeSkyViewAction)
                    case .purgeElements:
                        print(realtimeSkyViewAction)
                    }
                case .realtimeSkyOutput(let realtimeSkyViewOutput):
                    switch realtimeSkyViewOutput {

                    case .propagatedCurrentEphemerides(let results, satellites: _, let partialErrors, let observer, let julianDate):
                        print("propagatedCurrentEphemerides(results.count: \(results.count), partialErrors: \(partialErrors), observer: \(observer), julianDate: \(julianDate))")
                    case .failedToPropagateCurrentEphemerides(let error, let observer, let julianDate):
                        print("failedToPropagatedCurrentEphemerides(error: \(error), observer: \(observer), julianDate: \(julianDate))")
                    }
                case .detailedPassView(let detailedPassAction):
                    print(detailedPassAction)
                }
            }
        }
    }
}
