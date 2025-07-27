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

extension EffectMiddleware where InputActionType == AppAction, OutputActionType == AppAction, StateType == AppState, Dependencies == Void {
    public static var loggerMiddleware: EffectMiddleware<AppAction, AppAction, AppState, Void> {
        #if DEBUG
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
                    case .loadedSatelliteElements(let satelliteCategory, _, let selectNoradIndex, let calculatePass):
                        print("loadedSatelliteElements(\(satelliteCategory), selectNoradIndex: \(String(describing: selectNoradIndex)), calculatePass: \(calculatePass != nil))")
                    case .failedLoadingElements(_, _):
                        print(elementsLoaderOutput)
                    }
                case .rootView(let rootViewAction):
                    print(rootViewAction)
                case .satelliteOverview(let satelliteOverviewViewAction):
                    print(satelliteOverviewViewAction)
                case .satelliteCategory(let satelliteCateogryViewAction):
                    print(satelliteCateogryViewAction)
                case .satelliteListView(let satelliteListViewAction):
                    print(satelliteListViewAction)
                case .satelliteListOutput(let satelliteListViewOutput):
                    switch satelliteListViewOutput {
                    case .filteredSatellites(let map, searchText: let searchText, category: let category):
                        if let map = map {
                            print("filteredSatellites(\(map.count), searchText: \(searchText), category: \(category))")
                        } else {
                            print("filteredSatellites(nil, searchText: \(searchText), category: \(category))")
                        }
                    }
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
                case .onboarding(let onboardingAction):
                    print(onboardingAction)
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
