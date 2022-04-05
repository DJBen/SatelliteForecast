//
//  BackgroundSkyResources.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/3/22.
//

import BTree
import SatelliteKit

/// A key uniquely determining the rendering of a sky chart's background. Same key is guaranteed to render the same background.
public struct BackgroundSkyKey: Equatable, Hashable {
    public let observer: LatLonAlt
    public let configs: BackgroundSkyConfigs

    public init(
        observer: LatLonAlt,
        configs: BackgroundSkyConfigs
    ) {
        self.observer = observer
        self.configs = configs
    }
}

public struct BackgroundSkyResources {
    public var rasterizedBackgroundSky: [BackgroundSkyKey: [Double: UIImage]] = [:]

    public var previewBackgroundSkies: [BackgroundSkyKey: [Double: UIImage]] = [:]

    public init(
        rasterizedBackgroundSky: [BackgroundSkyKey: [Double: UIImage]] = [:],
        previewBackgroundSkies: [BackgroundSkyKey: [Double: UIImage]] = [:]
    ) {
        self.rasterizedBackgroundSky = rasterizedBackgroundSky
        self.previewBackgroundSkies = previewBackgroundSkies
    }
}

extension BackgroundSkyResources: Equatable {}
