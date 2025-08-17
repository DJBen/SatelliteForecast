//
//  SkyChartTheme.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 4/9/22.
//

import Foundation
import UIKit
import StarryNight

public enum SkyChartTheme {
    public static func starColor(
        traitCollection: UITraitCollection
    ) -> UIColor {
        UIColor(
            named: "star",
            in: .module,
            compatibleWith: traitCollection
        )!
    }

    public static func constellationLineColor(
        traitCollection: UITraitCollection
    ) -> UIColor {
        UIColor(
            named: "constellationLine",
            in: .module,
            compatibleWith: traitCollection
        )!
    }

    public static func skyChartStrokeColor(
        traitCollection: UITraitCollection
    ) -> UIColor {
        UIColor(
            named: "skyChartStroke",
            in: .module,
            compatibleWith: traitCollection
        )!
    }

    public static func satellitePathColor(
        illuminated: Bool,
        traitCollection: UITraitCollection
    ) -> UIColor {
        UIColor(
            named: illuminated ? "satellitePath_illuminated" : "satellitePath_notIlluminated",
            in: .module,
            compatibleWith: traitCollection
        )!
    }
    
    /// Returns the color for a star based on its spectral class
    /// Maps spectral classes O, B, A, F, G, K, M to realistic stellar colors
    /// Returns white for unknown or missing spectral classes
    public static func starColor(
        spectralClass: String?,
        traitCollection: UITraitCollection
    ) -> UIColor {
        guard let spectralClass = spectralClass?.uppercased().first else {
            // Default to white for missing spectral class
            return UIColor.white
        }
        
        switch spectralClass {
        case "O":
            // O-type stars: Very hot, blue stars (30,000-60,000K)
            return UIColor(red: 0.6, green: 0.7, blue: 1.0, alpha: 1.0)
        case "B":
            // B-type stars: Hot, blue-white stars (10,000-30,000K)
            return UIColor(red: 0.7, green: 0.8, blue: 1.0, alpha: 1.0)
        case "A":
            // A-type stars: Hot, white stars (7,500-10,000K)
            return UIColor(red: 0.9, green: 0.9, blue: 1.0, alpha: 1.0)
        case "F":
            // F-type stars: Yellow-white stars (6,000-7,500K)
            return UIColor(red: 1.0, green: 0.95, blue: 0.9, alpha: 1.0)
        case "G":
            // G-type stars: Yellow stars like our Sun (5,200-6,000K)
            return UIColor(red: 1.0, green: 0.9, blue: 0.7, alpha: 1.0)
        case "K":
            // K-type stars: Orange stars (3,700-5,200K)
            return UIColor(red: 1.0, green: 0.8, blue: 0.6, alpha: 1.0)
        case "M":
            // M-type stars: Red stars (2,400-3,700K)
            return UIColor(red: 1.0, green: 0.6, blue: 0.4, alpha: 1.0)
        default:
            // Unknown spectral class, default to white
            return UIColor.white
        }
    }
}
