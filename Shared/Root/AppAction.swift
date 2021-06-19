//
//  AppAction.swift
//  SatelliteKitTests
//
//  Created by Ben Lu on 6/5/21.
//

import Foundation

enum AppAction {
    case appDelegate(AppDelegateAction)
    case coreLocationInput(CoreLocationInputAction)
    case coreLocationOutput(CoreLocationOutputAction)
    case tleLoaderInput(TLELoaderInputAction)
    case tleLoaderOutput(TLELoaderOutputAction)
    case satelliteListView(SatelliteListViewAction)
    case allPassesView(AllPassesViewAction)
    case passView(PassViewAction)
    case satelliteElevationGraph(SatelliteElevationGraphAction)
    case skyChart(SkyChartAction)
    case tlePropagator(TLEPropagatorAction)
    case timer(TimerAction)
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

    public var coreLocationInput: CoreLocationInputAction? {
        get {
            guard case let .coreLocationInput(value) = self else { return nil }
            return value
        }
        set {
            guard case .coreLocationInput = self, let newValue = newValue else { return }
            self = .coreLocationInput(newValue)
        }
    }

    public var coreLocationOutput: CoreLocationOutputAction? {
        get {
            guard case let .coreLocationOutput(value) = self else { return nil }
            return value
        }
        set {
            guard case .coreLocationOutput = self, let newValue = newValue else { return }
            self = .coreLocationOutput(newValue)
        }
    }

    public var tleLoaderInput: TLELoaderInputAction? {
        get {
            guard case let .tleLoaderInput(value) = self else { return nil }
            return value
        }
        set {
            guard case .tleLoaderInput = self, let newValue = newValue else { return }
            self = .tleLoaderInput(newValue)
        }
    }

    public var tleLoaderOutput: TLELoaderOutputAction? {
        get {
            guard case let .tleLoaderOutput(value) = self else { return nil }
            return value
        }
        set {
            guard case .tleLoaderOutput = self, let newValue = newValue else { return }
            self = .tleLoaderOutput(newValue)
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
}
