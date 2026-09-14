//
//  SkyChartResources.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 7/4/21.
//

import BTree
import UIKit

/// Appearance belongs in the key: a dark image must never satisfy a light request.
public struct SkyPathKey: Hashable {
    public let pass: Pass
    public let isDark: Bool
    public init(pass: Pass, isDark: Bool) { self.pass = pass; self.isDark = isDark }
}

/// The root state of sky charts.
public struct SkyChartResources: Equatable {
    public var detailedSatellitePaths: [SkyPathKey: UIImage] = [:]

    /// A cache of the satellite paths that are ready for display.
    /// Instead of redrawing the pass consisting of thousands of points at each display,
    /// the cached version is just a cheap `UIImage`.
    public var rasterizedSatellitePaths: [SkyPathKey: UIImage] = [:]

    public var previewSatellitePaths: [SkyPathKey: UIImage] = [:]

    public var onboardingSatellitePaths: [SkyPathKey: UIImage] = [:]

    public init(
        detailedSatellitePaths: [SkyPathKey: UIImage] = [:],
        rasterizedSatellitePaths: [SkyPathKey: UIImage] = [:],
        previewSatellitePaths: [SkyPathKey: UIImage] = [:],
        onboardingSatellitePaths: [SkyPathKey: UIImage] = [:]
    ) {
        self.detailedSatellitePaths = detailedSatellitePaths
        self.rasterizedSatellitePaths = rasterizedSatellitePaths
        self.previewSatellitePaths = previewSatellitePaths
        self.onboardingSatellitePaths = onboardingSatellitePaths
    }

    public func dataSource(for quality: ChartQuality) -> [SkyPathKey: UIImage] {
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
