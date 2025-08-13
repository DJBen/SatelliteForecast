//
//  VSOP87.swift
//  VSOP87
//
//  Created by Ben Lu on 3/17/22.
//  Copyright © 2022 Ben Lu. All rights reserved.
//

import Foundation
@preconcurrency import SatelliteKit

extension SolarSystemBody {
    public func eci(julianDay: Double) -> Vector {
        VSOP87.getBodyECICoordinate(self, julianDay: julianDay)
    }
    
    /// Diffuse sphere model for phase integral: q(α) = (2/3) * ((1 - α/180°) * cos(α) + (1/π) * sin(α))
    /// Returns -2.5 * log10(q(α)) for the diffuse sphere model
    private func diffuseSpherePhaseIntegral(phaseAngleDegrees alpha: Double) -> Double {
        let alphaRadians = alpha * .pi / 180.0
        let alphaRatio = alpha / 180.0
        let q_alpha = (2.0/3.0) * ((1.0 - alphaRatio) * cos(alphaRadians) + (1.0 / .pi) * sin(alphaRadians))
        return -2.5 * log10(q_alpha)
    }
    
    /// Absolute magnitude (H) - brightness parameter used in magnitude calculations
    public var absoluteMagnitude: Double {
        switch self {
        case .mercury:
            return -0.613
        case .venus:
            return -4.384
        case .earth:
            return -3.99
        case .moon:
            return 0.28
        case .mars:
            return -1.601
        case .jupiter:
            return -9.395
        case .saturn:
            return -8.914
        case .uranus:
            return -7.110
        case .neptune:
            return -7.00
        case .sun, .earthMoonBarycenter:
            return 0.0 // Not applicable
        }
    }
    
    /// Phase integral magnitude correction: -2.5 * log10(q(α))
    /// Returns a function that calculates the magnitude correction based on phase angle α in degrees
    public func magnitudePhaseIntegral(phaseAngleDegrees alpha: Double) -> Double {
        precondition(alpha >= 0 && alpha <= 180, "Phase angle must be between 0° and 180°, got \(alpha)°")
        
        switch self {
        case .mercury:
            return 6.328e-2 * alpha - 1.6336e-3 * pow(alpha, 2) + 3.3644e-5 * pow(alpha, 3) - 3.4265e-7 * pow(alpha, 4) + 1.6893e-9 * pow(alpha, 5) - 3.0334e-12 * pow(alpha, 6)
            
        case .venus:
            if alpha <= 163.7 {
                return -1.044e-3 * alpha + 3.687e-4 * pow(alpha, 2) - 2.814e-6 * pow(alpha, 3) + 8.938e-9 * pow(alpha, 4)
            } else if alpha < 179.0 {
                return 240.44228 - 2.81914 * alpha + 8.39034e-3 * pow(alpha, 2)
            } else {
                return diffuseSpherePhaseIntegral(phaseAngleDegrees: alpha)
            }
            
        case .earth:
            return -1.060e-3 * alpha + 2.054e-4 * pow(alpha, 2)
            
        case .moon:
            // For simplicity, using the "before full Moon" formula for all cases
            // In a complete implementation, you would need to determine if it's before or after full Moon
            if alpha <= 150.0 {
                return 2.9994e-2 * alpha - 1.6057e-4 * pow(alpha, 2) + 3.1543e-6 * pow(alpha, 3) - 2.0667e-8 * pow(alpha, 4) + 6.2553e-11 * pow(alpha, 5)
            } else {
                return diffuseSpherePhaseIntegral(phaseAngleDegrees: alpha)
            }
            
        case .mars:
            if alpha <= 50.0 {
                return 2.267e-2 * alpha - 1.302e-4 * pow(alpha, 2)
            } else if alpha <= 120.0 {
                return 1.234 - 2.573e-2 * alpha + 3.445e-4 * pow(alpha, 2)
            } else {
                return diffuseSpherePhaseIntegral(phaseAngleDegrees: alpha)
            }
            
        case .jupiter:
            if alpha <= 12.0 {
                return -3.7e-4 * alpha + 6.16e-4 * pow(alpha, 2)
            } else {
                let alphaRatio = alpha / 180.0
                let logTerm = 1 - 1.507 * alphaRatio - 0.363 * pow(alphaRatio, 2) - 0.062 * pow(alphaRatio, 3) + 2.809 * pow(alphaRatio, 4) - 1.876 * pow(alphaRatio, 5)
                return -0.033 - 2.5 * log10(logTerm)
            }
            
        case .saturn:
            // Using the formula with rings
            if alpha < 6.5 {
                // Note: β (ring inclination angle) is not provided, using a typical value of 26.7° for Saturn's rings
                let beta = 26.7 * .pi / 180.0 // Convert to radians
                return -1.825 * sin(beta) + 2.6e-2 * alpha - 0.378 * sin(beta) * exp(-2.25 * alpha)
            } else if alpha < 150.0 {
                // Fall back to globe alone formula for larger phase angles
                return 0.026 + 2.446e-4 * alpha + 2.672e-4 * pow(alpha, 2) - 1.505e-6 * pow(alpha, 3) + 4.767e-9 * pow(alpha, 4)
            } else {
                return diffuseSpherePhaseIntegral(phaseAngleDegrees: alpha)
            }
            
        case .uranus:
            if alpha < 3.1 {
                // Note: φ' is a small correction term depending on Uranus' sub-Earth and sub-solar latitudes
                let phi_prime = 0.0
                return -8.4e-4 * phi_prime + 6.587e-3 * alpha + 1.045e-4 * pow(alpha, 2)
            } else {
                return diffuseSpherePhaseIntegral(phaseAngleDegrees: alpha)
            }
            
        case .neptune:
            if alpha < 133.0 {
                return 7.944e-3 * alpha + 9.617e-5 * pow(alpha, 2)
            } else {
                return diffuseSpherePhaseIntegral(phaseAngleDegrees: alpha)
            }
            
        case .sun, .earthMoonBarycenter:
            return 0.0 // Not applicable
        }
    }
    
    /// Calculate the apparent magnitude of the planet as seen from Earth
    /// Uses the formula: m = H + 5 * log10((d_BS * d_BO) / d_0^2) + phaseIntegralCorrection
    /// where α is the phase angle calculated using the law of cosines
    ///
    /// - Parameters:
    ///   - julianDay: Julian day for the calculation
    /// - Returns: Apparent magnitude of the planet, or nil if not applicable (earthMoonBarycenter)
    public func apparentMagnitude(julianDay: Double) -> Double? {
        guard self != .sun else {
            return -26.74
        }
        guard self != .earthMoonBarycenter else {
            return nil // Earth-Moon barycenter is not a visible object
        }
        
        let d_0 = 1.0 // 1 AU in AU (reference distance)
        let au2Km = 149597870.7 // km per AU
        
        // Get heliocentric positions
        let planetHeliocentricPosition = VSOP87.getBodyHeliocentricEclipticCoordinate(self, julianDay: julianDay)
        let earthHeliocentricPosition = VSOP87.getBodyHeliocentricEclipticCoordinate(.earth, julianDay: julianDay)
        
        // Convert to km
        let planetPosition = Vector(planetHeliocentricPosition) * au2Km
        let earthPosition = Vector(earthHeliocentricPosition) * au2Km
        let sunPosition = Vector(0, 0, 0) // Sun is at origin in heliocentric coordinates
        
        // Observer position is Earth center in heliocentric coordinates
        let observerHeliocentricPosition = earthPosition
        
        // Calculate distances in km
        let d_BS = (planetPosition - sunPosition).magnitude() // Body-Sun distance
        let d_BO = (planetPosition - observerHeliocentricPosition).magnitude() // Body-Observer distance  
        let d_OS = (observerHeliocentricPosition - sunPosition).magnitude() // Observer-Sun distance
        
        // Calculate phase angle using law of cosines
        let cosAlpha = (d_BO * d_BO + d_BS * d_BS - d_OS * d_OS) / (2.0 * d_BO * d_BS)
        let alpha = acos(max(-1.0, min(1.0, cosAlpha))) // Clamp to valid range for acos
        let alphaDegrees = alpha * 180.0 / .pi
        
        // Get absolute magnitude
        let H = self.absoluteMagnitude
        
        // Calculate distance factor (converting distances to AU for the formula)
        let d_BS_au = d_BS / au2Km
        let d_BO_au = d_BO / au2Km
        let distanceFactor = 5.0 * log10((d_BS_au * d_BO_au) / (d_0 * d_0))
        
        // Get phase integral correction
        let phaseIntegralCorrection = self.magnitudePhaseIntegral(phaseAngleDegrees: alphaDegrees)
        
        // Calculate apparent magnitude
        let apparentMag = H + distanceFactor + phaseIntegralCorrection
        
        return apparentMag
    }
}

extension VSOP87 {
    public static func getBodyECICoordinate(
        _ solarSystemBody: SolarSystemBody,
        julianDay: Double
    ) -> Vector {
        let geocentricEclipticalCoordinate = getBodyHeliocentricEclipticCoordinate(solarSystemBody, julianDay: julianDay) - getBodyHeliocentricEclipticCoordinate(.earth, julianDay: julianDay)
        let (x, y, z) = (geocentricEclipticalCoordinate.x, geocentricEclipticalCoordinate.y, geocentricEclipticalCoordinate.z)

        // https://en.wikipedia.org/wiki/Axial_tilt#Earth
        let obliquity: Double = {
            let t = (julianDay - 2451545.0) / (365.25 * 10_000)
            var term = [Double](repeating: 0, count: 11)
            term[0] = 23 + 26 / 60 + 21.448 / 3600.0
            term[1] = -4680.93 / 3600.0 * t
            term[2] = -1.55 / 3600.0 * pow(t, 2)
            term[3] = 1999.25 / 3600.0 * pow(t, 3)
            term[4] = -51.38 / 3600.0 * pow(t, 4)
            term[5] = -249.67 / 3600.0 * pow(t, 5)
            term[6] = -39.05 / 3600.0 * pow(t, 6)
            term[7] = 7.12 / 3600.0 * pow(t, 7)
            term[8] = 27.87 / 3600.0 * pow(t, 8)
            term[9] = 5.79 / 3600.0 * pow(t, 9)
            term[10] = 2.45 / 3600.0 * pow(t, 10)
            return term.reduce(0, +)
        }()

        let sini = sin(obliquity * deg2rad)
        let cosi = cos(obliquity * deg2rad)
        let eci_y = cosi * y - sini * z
        let eci_z = sini * y + cosi * z
        return Vector(x, eci_y, eci_z)
    }
}

extension Vector {
    public init(_ rectangularCoordinate: RectangularCoordinate) {
        self.init(rectangularCoordinate.x, rectangularCoordinate.y, rectangularCoordinate.z)
    }
}
