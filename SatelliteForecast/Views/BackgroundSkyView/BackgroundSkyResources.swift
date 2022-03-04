//
//  BackgroundSkyResources.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/3/22.
//

import BTree

struct BackgroundSkyResources {
    var rasterizedBackgroundSky: [BackgroundSkyKey: BTree<Double, UIImage>] = [:]

    var previewBackgroundSkies: [BackgroundSkyKey: BTree<Double, UIImage>] = [:]
}

extension BackgroundSkyResources: Equatable {}
