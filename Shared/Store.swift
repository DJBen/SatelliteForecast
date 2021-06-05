//
//  Store.swift
//  SatelliteForcast
//
//  Created by Ben Lu on 6/4/21.
//

import SatelliteKit
import SatelliteForcastCore
import SwiftRex
import CombineRex

struct AppState: Equatable {
    var satellites: Loadable<[Satellite]>
    var observerCoordinate: LatLonAlt
    var allSnapshots: [String: [SatelliteSnapshot]] = [:]
    var currentSatelliteNorad: String?
    var dateRange: Range<Date>
    var satelliteElevationGraphConfigs: SatelliteElevationGraphConfigs = .preset

    var coreLocationState: CoreLocationState = .empty

    static var empty: AppState {
        AppState(
            satellites: .neverLoaded,
            // Default to a dummy address
            // 2000 Broadway, Redwood City, CA 94063
            observerCoordinate: LatLonAlt(lat: 37.486743000691185, lon: -122.22655970246515, alt: 0),
            dateRange: Date().advanced(by: -60 * 60 * 2)..<Date().advanced(by: 60 * 60 * 22)
        )
    }

    var currentSatelliteSnapshots: [SatelliteSnapshot] {
        guard let currentSatelliteNorad = currentSatelliteNorad else {
            return []
        }
        return allSnapshots[currentSatelliteNorad] ?? []
    }
}

enum AppAction {
    case coreLocationInput(CoreLocationInputAction)
    case coreLocationOutput(CoreLocationOutputAction)
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
}

class Store: ReduxStoreBase<AppAction, AppState> {
    static let shared = Store()

    private init() {
        super.init(
            subject: .combine(initialValue: .empty),
            reducer: Reducer<CoreLocationOutputAction, CoreLocationState>.coreLocationReducer
                .lift(action: \.coreLocationOutput, state: \.coreLocationState),
            middleware: CoreLocationMiddleware()
                .lift(
                    inputAction: \AppAction.coreLocationInput,
                    outputAction: { AppAction.coreLocationOutput($0) },
                    state: \.coreLocationState
                )
//                <> LoggerMiddleware()
                .eraseToAnyMiddleware()
        )
    }
}
