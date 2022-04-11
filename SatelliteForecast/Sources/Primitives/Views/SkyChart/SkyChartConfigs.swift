//
//  SkyChartConfigs.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/16/21.
//

import Foundation
import CoreGraphics

public struct BackgroundSkyConfigs: Equatable, Hashable {
    public enum Stars: Equatable, Hashable {
        case none
        case limitedMagnitude(Double)
    }
    public var stars: Stars = .limitedMagnitude(4.5)

    /// A mapping function between the star's magitude to the display radius
    public struct StarMagToDisplayRadiusMappingFunction: Equatable, Hashable {
        public let multiplier: Double
        public let exponent: Double
        public let minimum: Double

        public init(multipler: Double = 3, exponent: Double = -0.425, minimum: Double = 0.0) {
            self.multiplier = multipler
            self.exponent = exponent
            self.minimum = minimum
        }

        public func apply(_ value: Double) -> CGFloat {
            max(minimum, CGFloat(multiplier * exp(exponent * value)))
        }
    }

    public var starMagToDisplayRadiusMappingFunction = StarMagToDisplayRadiusMappingFunction()
    public var hidesStarsDuringDay: Bool = true
    public var showConstellationLines: Bool = true

    public enum PlantaryBody: Equatable, CaseIterable, Hashable {
        case sun
        case moon
        case mercury
        case venus
        case mars
        case jupiter
        case saturn
    }

    public var visibleBodies: [PlantaryBody] = PlantaryBody.allCases

    public enum PlantaryBodyLabel: Equatable, Hashable {
        case text
        case symbol
    }

    public var bodySymbol: PlantaryBodyLabel = .text

    public static var preset: BackgroundSkyConfigs {
        BackgroundSkyConfigs()
    }

    public init(
        stars: BackgroundSkyConfigs.Stars = .limitedMagnitude(4.5),
        starMagToDisplayRadiusMappingFunction: BackgroundSkyConfigs.StarMagToDisplayRadiusMappingFunction = StarMagToDisplayRadiusMappingFunction(),
        hidesStarsDuringDay: Bool = true,
        showConstellationLines: Bool = true,
        visibleBodies: [BackgroundSkyConfigs.PlantaryBody] = PlantaryBody.allCases,
        bodySymbol: BackgroundSkyConfigs.PlantaryBodyLabel = .text
    ) {
        self.stars = stars
        self.starMagToDisplayRadiusMappingFunction = starMagToDisplayRadiusMappingFunction
        self.hidesStarsDuringDay = hidesStarsDuringDay
        self.showConstellationLines = showConstellationLines
        self.visibleBodies = visibleBodies
        self.bodySymbol = bodySymbol
    }
}

public struct BasicChartConfigs: Equatable, Hashable {
    public var showAzimuthTexts: Bool = true

    /// The degree interval between each pair of azimuth marks
    public var azimuthMarkInterval: Int = 15

    /// The length of azimuth marks
    public var azimuthMarkLength: CGFloat = 3

    public var showDirections: Bool = true

    public var directionTextOutset: CGFloat = 30

    public var showsAttitude: Bool = true

    public init(
        showAzimuthTexts: Bool = true,
        azimuthMarkInterval: Int = 15,
        azimuthMarkLength: CGFloat = 3,
        showDirections: Bool = true,
        directionTextOutset: CGFloat = 30,
        showsAttitude: Bool = true
    ) {
        self.showAzimuthTexts = showAzimuthTexts
        self.azimuthMarkInterval = azimuthMarkInterval
        self.azimuthMarkLength = azimuthMarkLength
        self.showDirections = showDirections
        self.directionTextOutset = directionTextOutset
        self.showsAttitude = showsAttitude
    }
}

public struct SkyChartConfigs: Equatable, Hashable {
    /// The background sky configuration
    public var backgroundSkyConfigs: BackgroundSkyConfigs = .preset

    public var basicChartConfigs: BasicChartConfigs = .init()

    public var showPassInfoLabels: Bool = true

    /// Whether to show more information when the user taps / drags on the passing trajectory, or taps on the label.
    public var showMoreInfoOnTap: Bool = true

    public static var preset: SkyChartConfigs {
        return SkyChartConfigs()
    }

    public static var preview: SkyChartConfigs {
        SkyChartConfigs(
            backgroundSkyConfigs: BackgroundSkyConfigs(
                stars: .limitedMagnitude(2.25),
                starMagToDisplayRadiusMappingFunction: BackgroundSkyConfigs.StarMagToDisplayRadiusMappingFunction(multipler: 1.5, exponent: -0.5),
                showConstellationLines: false,
                visibleBodies: [.sun, .moon],
                bodySymbol: .symbol
            ),
            basicChartConfigs: BasicChartConfigs(
                showAzimuthTexts: false,
                azimuthMarkInterval: 90,
                azimuthMarkLength: 2,
                showDirections: false,
                directionTextOutset: 30,
                showsAttitude: false
            ),
            showPassInfoLabels: false,
            showMoreInfoOnTap: false
        )
    }

    public init(
        backgroundSkyConfigs: BackgroundSkyConfigs = .preset,
        basicChartConfigs: BasicChartConfigs = .init(),
        showPassInfoLabels: Bool = true,
        showMoreInfoOnTap: Bool = true
    ) {
        self.backgroundSkyConfigs = backgroundSkyConfigs
        self.basicChartConfigs = basicChartConfigs
        self.showPassInfoLabels = showPassInfoLabels
        self.showMoreInfoOnTap = showMoreInfoOnTap
    }
}
