//
//  SkyChartConfigs.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/16/21.
//

import Foundation
import CoreGraphics

struct BackgroundSkyConfigs: Equatable, Hashable {
    enum Stars: Equatable, Hashable {
        case none
        case limitedMagnitude(Double)
    }
    var stars: Stars = .limitedMagnitude(4.5)

    /// A mapping function between the star's magitude to the display radius
    struct StarMagToDisplayRadiusMappingFunction: Equatable, Hashable {
        let multiplier: Double
        let exponent: Double

        init(multipler: Double = 3, exponent: Double = -0.425) {
            self.multiplier = multipler
            self.exponent = exponent
        }

        func apply(_ value: Double) -> CGFloat {
            CGFloat(multiplier * exp(exponent * value))
        }
    }

    var starMagToDisplayRadiusMappingFunction = StarMagToDisplayRadiusMappingFunction()
    var hidesStarsDuringDay: Bool = true
    var showConstellationLines: Bool = true

    enum PlantaryBody: Equatable, CaseIterable, Hashable {
        case sun
        case moon
        case mercury
        case venus
        case jupiter
        case saturn
    }

    var visibleBodies: [PlantaryBody] = PlantaryBody.allCases

    enum PlantaryBodyLabel: Equatable, Hashable {
        case text
        case symbol
    }

    var bodySymbol: PlantaryBodyLabel = .text

    static var preset: BackgroundSkyConfigs {
        BackgroundSkyConfigs()
    }
}

struct BasicChartConfigs: Equatable, Hashable {
    var showAzimuthTexts: Bool = true

    /// The degree interval between each pair of azimuth marks
    var azimuthMarkInterval: Int = 15

    /// The length of azimuth marks
    var azimuthMarkLength: CGFloat = 3

    var showDirections: Bool = true

    var directionTextOutset: CGFloat = 30
}

struct SkyChartConfigs: Equatable, Hashable {
    /// The background sky configuration
    var backgroundSkyConfigs: BackgroundSkyConfigs = .preset

    var basicChartConfigs: BasicChartConfigs = .init()

    var showPassInfoLabels: Bool = true

    static var preset: SkyChartConfigs {
        return SkyChartConfigs()
    }

    static var preview: SkyChartConfigs {
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
                directionTextOutset: 30
            ),
            showPassInfoLabels: false
        )
    }
}
