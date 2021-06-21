//
//  SkyChartConfigs.swift
//  SatelliteForcast (iOS)
//
//  Created by Ben Lu on 6/16/21.
//

import Foundation
import CoreGraphics

struct SkyChartConfigs {
    struct BackgroundSky {
        enum Stars {
            case none
            case limitedMagnitude(Double)
        }
        var stars: Stars = .limitedMagnitude(4.5)
        var starMagToDisplayRadius: (Double) -> CGFloat = { CGFloat(3 * exp(0.425 * -$0)) }
        var hidesStarsDuringDay: Bool = true
        var showConstellationLines: Bool = true

        struct PlantaryBody: OptionSet {
            let rawValue: Int

            static let sun = PlantaryBody(rawValue: 1 << 0)
            static let moon = PlantaryBody(rawValue: 1 << 1)
            static let mercury = PlantaryBody(rawValue: 1 << 2)
            static let venus = PlantaryBody(rawValue: 1 << 3)
            static let jupiter = PlantaryBody(rawValue: 1 << 4)
            static let saturn = PlantaryBody(rawValue: 1 << 5)

            static let all: PlantaryBody = [.sun, .moon, .mercury, .venus, .jupiter, .saturn]
        }

        var visibileBodies: PlantaryBody = .all

        enum PlantaryBodyLabel {
            case text
            case symbol
        }

        var bodySymbol: PlantaryBodyLabel = .text

        static var preset: BackgroundSky {
            BackgroundSky()
        }
    }

    /// The background sky configuration
    var backgroundSky: BackgroundSky = .preset

    var showAzimuthTexts: Bool = true

    /// The degree interval between each pair of azimuth marks
    var azimuthMarkInterval: Int = 15

    /// The length of azimuth marks
    var azimuthMarkLength: CGFloat = 3

    var showDirections: Bool = true

    var directionTextOutset: CGFloat = 30

    var showPassInfoLabels: Bool = true

    static var preset: SkyChartConfigs {
        return SkyChartConfigs()
    }

    static var preview: SkyChartConfigs {
        SkyChartConfigs(
            backgroundSky: SkyChartConfigs.BackgroundSky(
                stars: .limitedMagnitude(2.25),
                starMagToDisplayRadius: { CGFloat(1.5 * exp(0.5 * -$0)) },
                showConstellationLines: false,
                visibileBodies: [.sun, .moon],
                bodySymbol: .symbol
            ),
            showAzimuthTexts: false,
            azimuthMarkInterval: 90,
            azimuthMarkLength: 2,
            showDirections: false,
            showPassInfoLabels: false
        )
    }
}
