//
//  SatelliteLoaderAction.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/4/21.
//

import BTree
import Foundation
import SatelliteForecastCore

enum SatelliteLoaderAction {
    case loadSatelliteCategory(SatelliteCategory, onCompletion: (Map<Int, SatelliteInfo>) -> AppAction? = { _ in nil })
}

enum SatelliteLoaderOutput {
    case loadedSatelliteInfo(SatelliteCategory, Map<Int, SatelliteInfo>)
    case failedLoadingTLEFile(SatelliteCategory, SatelliteLoaderError)
}
