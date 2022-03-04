//
//  AppAction.swift
//  SatelliteKitTests
//
//  Created by Ben Lu on 6/5/21.
//

import Foundation
import SatelliteKit

enum AppAction {
    case appDelegate(AppDelegateAction)
    case backgroundTask(BackgroundTask)
    case notification(NotificationAction)
    case location(LocationAction)
    case satelliteLoader(SatelliteLoaderAction)
    case satelliteLoaderOutput(SatelliteLoaderOutput)
    case satelliteOverview(SatelliteOverviewViewAction)
    case satelliteListView(SatelliteListViewAction)
    case singleSatelliteWrappingView(SingleSatelliteWrappingViewAction)
    case allPassesView(AllPassesViewAction)
    case passView(PassViewAction)
    case satelliteElevationGraph(SatelliteElevationGraphAction)
    case backgroundSky(BackgroundSkyViewAction)
    case backgroundSkyOutput(BackgroundSkyViewOutput)
    case skyChart(SkyChartAction)
    case tlePropagator(TLEPropagatorAction)
    case timer(TimerAction)
    case debugMenu(DebugMenuAction)
    case observerCell(ObserverCellAction)
    case alarmSettingsCell(AlarmSettingsCellAction)
    case alarmSettingsView(AlarmSettingsViewAction)
}

extension AppAction {
    public var appDelegate: AppDelegateAction? {
        get {
            guard case let .appDelegate(value) = self else { return nil }
            return value
        }
        set {
            guard case .appDelegate = self, let newValue = newValue else { return }
            self = .appDelegate(newValue)
        }
    }

    public var backgroundTask: BackgroundTask? {
        get {
            guard case let .backgroundTask(value) = self else { return nil }
            return value
        }
        set {
            guard case .backgroundTask = self, let newValue = newValue else { return }
            self = .backgroundTask(newValue)
        }
    }
    
    public var notification: NotificationAction? {
        get {
            guard case let .notification(value) = self else { return nil }
            return value
        }
        set {
            guard case .notification = self, let newValue = newValue else { return }
            self = .notification(newValue)
        }
    }

    public var location: LocationAction? {
        get {
            guard case let .location(value) = self else { return nil }
            return value
        }
        set {
            guard case .location = self, let newValue = newValue else { return }
            self = .location(newValue)
        }
    }

    public var satelliteLoader: SatelliteLoaderAction? {
        get {
            guard case let .satelliteLoader(value) = self else { return nil }
            return value
        }
        set {
            guard case .satelliteLoader = self, let newValue = newValue else { return }
            self = .satelliteLoader(newValue)
        }
    }

    public var satelliteLoaderOutput: SatelliteLoaderOutput? {
        get {
            guard case let .satelliteLoaderOutput(value) = self else { return nil }
            return value
        }
        set {
            guard case .satelliteLoaderOutput = self, let newValue = newValue else { return }
            self = .satelliteLoaderOutput(newValue)
        }
    }

    public var satelliteOverview: SatelliteOverviewViewAction? {
        get {
            guard case let .satelliteOverview(value) = self else { return nil }
            return value
        }
        set {
            guard case .satelliteOverview = self, let newValue = newValue else { return }
            self = .satelliteOverview(newValue)
        }
    }

    public var singleSatelliteWrappingView: SingleSatelliteWrappingViewAction? {
        get {
            guard case let .singleSatelliteWrappingView(value) = self else { return nil }
            return value
        }
        set {
            guard case .singleSatelliteWrappingView = self, let newValue = newValue else { return }
            self = .singleSatelliteWrappingView(newValue)
        }
    }

    public var satelliteListView: SatelliteListViewAction? {
        get {
            guard case let .satelliteListView(value) = self else { return nil }
            return value
        }
        set {
            guard case .satelliteListView = self, let newValue = newValue else { return }
            self = .satelliteListView(newValue)
        }
    }

    public var passView: PassViewAction? {
        get {
            guard case let .passView(value) = self else { return nil }
            return value
        }
        set {
            guard case .passView = self, let newValue = newValue else { return }
            self = .passView(newValue)
        }
    }

    public var allPassesView: AllPassesViewAction? {
        get {
            guard case let .allPassesView(value) = self else { return nil }
            return value
        }
        set {
            guard case .allPassesView = self, let newValue = newValue else { return }
            self = .allPassesView(newValue)
        }
    }

    public var satelliteElevationGraph: SatelliteElevationGraphAction? {
        get {
            guard case let .satelliteElevationGraph(value) = self else { return nil }
            return value
        }
        set {
            guard case .satelliteElevationGraph = self, let newValue = newValue else { return }
            self = .satelliteElevationGraph(newValue)
        }
    }

    public var backgroundSky: BackgroundSkyViewAction? {
        get {
            guard case let .backgroundSky(value) = self else { return nil }
            return value
        }
        set {
            guard case .backgroundSky = self, let newValue = newValue else { return }
            self = .backgroundSky(newValue)
        }
    }

    public var backgroundSkyOutput: BackgroundSkyViewOutput? {
        get {
            guard case let .backgroundSkyOutput(value) = self else { return nil }
            return value
        }
        set {
            guard case .backgroundSkyOutput = self, let newValue = newValue else { return }
            self = .backgroundSkyOutput(newValue)
        }
    }

    public var skyChart: SkyChartAction? {
        get {
            guard case let .skyChart(value) = self else { return nil }
            return value
        }
        set {
            guard case .skyChart = self, let newValue = newValue else { return }
            self = .skyChart(newValue)
        }
    }

    public var tlePropagator: TLEPropagatorAction? {
        get {
            guard case let .tlePropagator(value) = self else { return nil }
            return value
        }
        set {
            guard case .tlePropagator = self, let newValue = newValue else { return }
            self = .tlePropagator(newValue)
        }
    }

    public var timer: TimerAction? {
        get {
            guard case let .timer(value) = self else { return nil }
            return value
        }
        set {
            guard case .timer = self, let newValue = newValue else { return }
            self = .timer(newValue)
        }
    }

    public var debugMenu: DebugMenuAction? {
        get {
            guard case let .debugMenu(value) = self else { return nil }
            return value
        }
        set {
            guard case .debugMenu = self, let newValue = newValue else { return }
            self = .debugMenu(newValue)
        }
    }

    public var observerCell: ObserverCellAction? {
        get {
            guard case let .observerCell(value) = self else { return nil }
            return value
        }
        set {
            guard case .observerCell = self, let newValue = newValue else { return }
            self = .observerCell(newValue)
        }
    }
    
    public var alarmSettingsCell: AlarmSettingsCellAction? {
        get {
            guard case let .alarmSettingsCell(value) = self else { return nil }
            return value
        }
        set {
            guard case .alarmSettingsCell = self, let newValue = newValue else { return }
            self = .alarmSettingsCell(newValue)
        }
    }
    
    public var alarmSettingsView: AlarmSettingsViewAction? {
        get {
            guard case let .alarmSettingsView(value) = self else { return nil }
            return value
        }
        set {
            guard case .alarmSettingsView = self, let newValue = newValue else { return }
            self = .alarmSettingsView(newValue)
        }
    }
}
