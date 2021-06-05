//
//  AppAction.swift
//  SatelliteKitTests
//
//  Created by Ben Lu on 6/5/21.
//

import Foundation

enum AppAction {
    case coreLocationInput(CoreLocationInputAction)
    case coreLocationOutput(CoreLocationOutputAction)
    case tleLoaderInput(TLELoaderInputAction)
    case tleLoaderOutput(TLELoaderOutputAction)
    case satelliteListView(SatelliteListViewAction)
}

extension AppAction {
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
}
