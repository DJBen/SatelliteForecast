//
//  SkyChartTheme.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 4/9/22.
//

import Foundation

public enum SkyChartTheme {
    public static func starColor(
        traitCollection: UITraitCollection
    ) -> UIColor {
        UIColor(
            named: "star",
            in: .satelliteForecastImplResourcesBundle,
            compatibleWith: traitCollection
        )!
    }

    public static func constellationLineColor(
        traitCollection: UITraitCollection
    ) -> UIColor {
        UIColor(
            named: "constellationLine",
            in: .satelliteForecastImplResourcesBundle,
            compatibleWith: traitCollection
        )!
    }

    public static func skyChartStrokeColor(
        traitCollection: UITraitCollection
    ) -> UIColor {
        UIColor(
            named: "skyChartStroke",
            in: .satelliteForecastImplResourcesBundle,
            compatibleWith: traitCollection
        )!
    }

    public static func satellitePathColor(
        illuminated: Bool,
        traitCollection: UITraitCollection
    ) -> UIColor {
        UIColor(
            named: illuminated ? "satellitePath_illuminated" : "satellitePath_notIlluminated",
            in: .satelliteForecastImplResourcesBundle,
            compatibleWith: traitCollection
        )!
    }
}
