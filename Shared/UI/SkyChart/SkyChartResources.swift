//
//  SkyChartResources.swift
//  SatelliteForcast
//
//  Created by Ben Lu on 7/4/21.
//

import Foundation
import SatelliteForcastCore

/// The root state of sky charts.
struct SkyChartResources: Equatable {
    /// A cache of the satellite paths that are ready for display.
    /// Instead of redrawing the pass consisting of thousands of points at each display,
    /// the cached version is just a cheap `UIImage`.
    var rasterizedSatellitePaths: [Pass: [SkyChartUsage: UIImage]] = [:]

    var rasterizedBackgroundSky: [SkyChartBackgroundSkyKey: [SkyChartUsage: UIImage]] = [:]

    static var empty: SkyChartResources {
        return SkyChartResources()
    }
}
