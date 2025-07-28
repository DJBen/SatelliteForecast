//
//  SkyChartResources.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 7/4/21.
//

import BTree
import UIKit

/// The root state of sky charts.
public struct SkyChartResources: Equatable {
    public var detailedSatellitePaths: [Pass: UIImage] = [:]

    /// A cache of the satellite paths that are ready for display.
    /// Instead of redrawing the pass consisting of thousands of points at each display,
    /// the cached version is just a cheap `UIImage`.
    public var rasterizedSatellitePaths: [Pass: UIImage] = [:]

    public var previewSatellitePaths: [Pass: UIImage] = [:]

    public var onboardingSatellitePaths: [Pass: UIImage] = [:]

    public init(
        detailedSatellitePaths: [Pass: UIImage] = [:],
        rasterizedSatellitePaths: [Pass: UIImage] = [:],
        previewSatellitePaths: [Pass: UIImage] = [:],
        onboardingSatellitePaths: [Pass: UIImage] = [:]
    ) {
        self.detailedSatellitePaths = detailedSatellitePaths
        self.rasterizedSatellitePaths = rasterizedSatellitePaths
        self.previewSatellitePaths = previewSatellitePaths
        self.onboardingSatellitePaths = onboardingSatellitePaths
    }

    public func dataSource(for quality: ChartQuality) -> [Pass: UIImage] {
        switch quality {
        case .detailed:
            return detailedSatellitePaths
        case .full:
            return rasterizedSatellitePaths
        case .preview:
            return previewSatellitePaths
        case .onboarding:
            return onboardingSatellitePaths
        }
    }
}
