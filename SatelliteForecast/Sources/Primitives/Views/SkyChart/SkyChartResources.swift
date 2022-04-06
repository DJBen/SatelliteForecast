//
//  SkyChartResources.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 7/4/21.
//

import BTree
import SatelliteForecast

/// The root state of sky charts.
public struct SkyChartResources: Equatable {
    /// A cache of the satellite paths that are ready for display.
    /// Instead of redrawing the pass consisting of thousands of points at each display,
    /// the cached version is just a cheap `UIImage`.
    public var rasterizedSatellitePaths: [Pass: UIImage] = [:]

    public var previewSatellitePaths: [Pass: UIImage] = [:]

    public init(rasterizedSatellitePaths: [Pass : UIImage] = [:], previewSatellitePaths: [Pass : UIImage] = [:]) {
        self.rasterizedSatellitePaths = rasterizedSatellitePaths
        self.previewSatellitePaths = previewSatellitePaths
    }
}
