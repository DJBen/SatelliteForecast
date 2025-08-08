//
//  BackgroundSkyResources.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/3/22.
//

import BTree
@preconcurrency import SatelliteKit
import StarryNight
import UIKit

/// A key uniquely determining the rendering of a sky chart's background. Same key is guaranteed to render the same background.
public struct BackgroundSkyKey: Equatable, Hashable, Sendable {
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
    public var detailedBackgroundSkies: [BackgroundSkyKey: [Double: UIImage]] = [:]

    public var rasterizedBackgroundSky: [BackgroundSkyKey: [Double: UIImage]] = [:]

    public var previewBackgroundSkies: [BackgroundSkyKey: [Double: UIImage]] = [:]

    public var onboardingBackgroundSkies: [BackgroundSkyKey: [Double: UIImage]] = [:]

    public var allConstellations: [Constellation] = []
    
    public func dataSource(for quality: ChartQuality) -> [BackgroundSkyKey: [Double: UIImage]] {
        switch quality {
        case .detailed:
            return detailedBackgroundSkies
        case .full:
            return rasterizedBackgroundSky
        case .preview:
            return previewBackgroundSkies
        case .onboarding:
            return onboardingBackgroundSkies
        }
    }

    public init(
        detailedBackgroundSkies: [BackgroundSkyKey: [Double: UIImage]] = [:],
        rasterizedBackgroundSky: [BackgroundSkyKey: [Double: UIImage]] = [:],
        previewBackgroundSkies: [BackgroundSkyKey: [Double: UIImage]] = [:],
        onboardingBackgroundSkies: [BackgroundSkyKey: [Double: UIImage]] = [:],
        allConstellations: [Constellation] = []
    ) {
        self.detailedBackgroundSkies = detailedBackgroundSkies
        self.rasterizedBackgroundSky = rasterizedBackgroundSky
        self.previewBackgroundSkies = previewBackgroundSkies
        self.onboardingBackgroundSkies = onboardingBackgroundSkies
        self.allConstellations = allConstellations
    }
}

extension BackgroundSkyResources: Equatable {}
