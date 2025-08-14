//
//  SkyChartConfigs.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/16/21.
//

import Foundation
import CoreGraphics
import SolarSystem

public struct BackgroundSkyConfigs: Equatable, Hashable, Sendable {
    public enum Stars: Equatable, Hashable, Sendable {
        case none
        case brightest300
        case limitedMagnitude(Double)
    }

    public let stars: Stars

    /// A mapping function between the star's magitude to the display radius
    public struct StarMagToDisplayRadiusMappingFunction: Equatable, Hashable, Identifiable, Sendable {
        public let id: String
        public let apply: (Double) -> CGFloat

        public static func == (lhs: StarMagToDisplayRadiusMappingFunction, rhs: StarMagToDisplayRadiusMappingFunction) -> Bool {
            lhs.id == rhs.id
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }

        public init(id: String, apply: @escaping (Double) -> CGFloat) {
            self.id = id
            self.apply = apply
        }

        public static let `default`: StarMagToDisplayRadiusMappingFunction = {
            StarMagToDisplayRadiusMappingFunction(id: "default") { mag in
                min(12, max(exp(mag * -0.38) * 2.5, 0))
            }
        }()
    }

    public var starMagToDisplayRadiusMappingFunction: StarMagToDisplayRadiusMappingFunction
    public var hidesStarsDuringDay: Bool = true
    public var showConstellationLines: Bool = true

    public var visibleBodies: [SolarSystemBody] = [
        .sun,
        .moon,
        .mercury,
        .venus,
        .mars,
        .jupiter,
        .saturn,
        // Consider Uranus and Neptune
    ]

    public enum PlantaryBodyLabel: Equatable, Hashable, Sendable {
        case text
        case symbol
    }

    public var bodySymbol: PlantaryBodyLabel = .text

    public static var preset: BackgroundSkyConfigs {
        BackgroundSkyConfigs()
    }

    public init(
        stars: BackgroundSkyConfigs.Stars = .limitedMagnitude(4.5),
        starMagToDisplayRadiusMappingFunction: BackgroundSkyConfigs.StarMagToDisplayRadiusMappingFunction = .default,
        hidesStarsDuringDay: Bool = true,
        showConstellationLines: Bool = true,
        visibleBodies: [SolarSystemBody] = [
            .sun,
            .moon,
            .mercury,
            .venus,
            .mars,
            .jupiter,
            .saturn,
            // Consider Uranus and Neptune
        ],
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

public struct BasicChartConfigs: Equatable, Hashable, Sendable {
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

public struct SkyChartConfigs: Equatable, Hashable, Sendable {
    /// The background sky configuration
    public var backgroundSkyConfigs: BackgroundSkyConfigs = .preset

    public var basicChartConfigs: BasicChartConfigs = .init()

    /// Show labels about the important event during a pass.
    public var showPassInfoLabels: Bool = true

    public static var preset: SkyChartConfigs {
        return SkyChartConfigs()
    }

    public static var preview: SkyChartConfigs {
        SkyChartConfigs(
            backgroundSkyConfigs: BackgroundSkyConfigs(
                stars: .limitedMagnitude(2.8),
                starMagToDisplayRadiusMappingFunction: BackgroundSkyConfigs.StarMagToDisplayRadiusMappingFunction(id: "preview", apply: { mag in
                    min(8, max(exp(mag * -0.325) * 1.4, 0))
                }),
                showConstellationLines: false,
                visibleBodies: [.sun, .moon, .venus, .jupiter],
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
            showPassInfoLabels: false
        )
    }

    public init(
        backgroundSkyConfigs: BackgroundSkyConfigs = .preset,
        basicChartConfigs: BasicChartConfigs = .init(),
        showPassInfoLabels: Bool = true
    ) {
        self.backgroundSkyConfigs = backgroundSkyConfigs
        self.basicChartConfigs = basicChartConfigs
        self.showPassInfoLabels = showPassInfoLabels
    }
}
