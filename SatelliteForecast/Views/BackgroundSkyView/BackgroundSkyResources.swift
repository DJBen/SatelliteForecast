//
//  BackgroundSkyResources.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/3/22.
//

import BTree

struct BackgroundSkyResources {
    var rasterizedBackgroundSky: [BackgroundSkyKey: [Double: UIImage]] = [:]

    var previewBackgroundSkies: [BackgroundSkyKey: [Double: UIImage]] = [:]
}

extension BackgroundSkyResources: Equatable {}
