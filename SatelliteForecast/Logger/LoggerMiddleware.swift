//
//  LoggerMiddleware.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 2/10/22.
//

import Combine
import CombineRex

extension EffectMiddleware where InputActionType == AppAction, OutputActionType == AppAction, StateType == AppState, Dependencies == Void {
    static var loggerMiddleware: EffectMiddleware<AppAction, AppAction, AppState, Void> {
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
                case .tleLoader(let tleLoaderAction):
                    print(tleLoaderAction)
                case .tleLoaderOutput(let tleLoaderOutput):
                    switch tleLoaderOutput {
                    case .loadedSatelliteTLEs(let satelliteCategory, _, let selectSpecialNoradIndex, let selectNoradIndex, let calculatePass):
                        print("loadedSatelliteTLEs(\(satelliteCategory), selectSpecialNoradIndex: \(String(describing: selectSpecialNoradIndex)), selectNoradIndex: \(String(describing: selectNoradIndex)), calculatePass: \(calculatePass != nil))")
                    case .failedLoadingTLEFile(_, _):
                        print(tleLoaderOutput)
                    }
                case .rootView(let rootViewAction):
                    print(rootViewAction)
                case .satelliteOverview(let satelliteOverviewViewAction):
                    print(satelliteOverviewViewAction)
                case .satelliteListView(let satelliteListViewAction):
                    print(satelliteListViewAction)
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
                case .tlePropagator(let tlePropagatorAction):
                    switch tlePropagatorAction {
                    case .foundPassesAndSnapshots(let passSnapshotList, let noradIndex, let observer):
                        print("foundPassesAndSnapshots(passes: \(passSnapshotList.count), noradIndex: \(noradIndex), observer: \(observer))")
                    case .propagatedSnapshots(let snapshots, let noradIndex, let observer):
                        print("propagatedSnapshots(snapshots: \(snapshots.count), noradIndex: \(noradIndex), observer: \(observer))")
                    case .purgePassesAndSnapshots:
                        print(tlePropagatorAction)
                    }
                case .timer(let timerAction):
                    print(timerAction)
                case .debugMenu(let debugMenuAction):
                    print(debugMenuAction)
                case .observerCell(let observerCellAction):
                    print(observerCellAction)
                case .alarmSettingsCell(let alarmSettingsCellAction):
                    print(alarmSettingsCellAction)
                case .alarmSettingsView(let alarmSettingsViewAction):
                    print(alarmSettingsViewAction)
                case .realtimeSky(let realtimeSkyViewAction):
                    switch realtimeSkyViewAction {
                    case .propagateCurrentEphemerides(let tles, let observer, let julianDate):
                        print("propagateCurrentEphemerides(tles.count: \(tles.count), observer: \(observer), julianDate: \(julianDate))")
                    case .setRealtimeSkyViewActive(_):
                        print(realtimeSkyViewAction)
                    }
                case .realtimeSkyOutput(let realtimeSkyViewOutput):
                    print(realtimeSkyViewOutput)
                }
            }
        }
    }
}
