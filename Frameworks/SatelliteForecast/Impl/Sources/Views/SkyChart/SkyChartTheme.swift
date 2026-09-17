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
    /// Soft, compact point-spread profile shared by stars and unresolved planets.
    /// Radii are chart points; spectral color is retained through the halo.
    static func drawPointSource(in context: CGContext, at point: CGPoint, radius: CGFloat, color: UIColor, magnitude: Double) {
        guard radius.isFinite, radius > 0 else { return }
        let radius = min(radius, 4.32)
        let magnitude = magnitude.isFinite ? magnitude : 6
        let intensity = 0.35 + 0.65 / (1 + pow(10, 0.3 * (magnitude - 3)))
        let colors = [color.withAlphaComponent(0.95 * intensity).cgColor,
                      color.withAlphaComponent(0.85 * intensity).cgColor,
                      color.withAlphaComponent(0.16 * intensity).cgColor,
                      color.withAlphaComponent(0).cgColor] as CFArray
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                        colors: colors, locations: [0, 0.3, 0.6, 1]) else { return }
        context.drawRadialGradient(gradient, startCenter: point, startRadius: 0,
                                   endCenter: point, endRadius: radius * 1.8, options: [])
    }

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
        if traitCollection.userInterfaceStyle != .dark {
            let darkColor = starColor(spectralClass: spectralClass, traitCollection: UITraitCollection(userInterfaceStyle: .dark))
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            darkColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            return UIColor(red: red * 0.45, green: green * 0.45, blue: blue * 0.45, alpha: alpha)
        }
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
