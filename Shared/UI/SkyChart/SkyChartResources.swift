//
//  SkyChartResources.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 7/4/21.
//

import Foundation
import BTree
import SatelliteForecastCore

/// The root state of sky charts.
struct SkyChartResources: Equatable {
    enum Quality {
        case full
        case preview
    }

    /// A cache of the satellite paths that are ready for display.
    /// Instead of redrawing the pass consisting of thousands of points at each display,
    /// the cached version is just a cheap `UIImage`.
    var rasterizedSatellitePaths: [Pass: UIImage] = [:]

    var previewSatellitePaths: [Pass: UIImage] = [:]

    var rasterizedBackgroundSky: [SkyChartBackgroundSkyKey: BTree<Double, UIImage>] = [:]

    var previewBackgroundSkies: [SkyChartBackgroundSkyKey: BTree<Double, UIImage>] = [:]

    static var empty: SkyChartResources {
        return SkyChartResources()
    }
}
