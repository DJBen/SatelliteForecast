//
//  AstroAlgorithms.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/2/21.
//

import SatelliteKit
import Darwin

public enum AstroAlgorithms {
    /// Whether two objects have line of sight (and not blocked by earth).
    ///
    /// One of the object's geocentric coordinate can be replaced by sun's coordinate
    /// to determine if the object is illuminated. Note that this approach assumes a cynlindrical shadow, instead of the actual conic shaow.
    /// - Parameters:
    ///   - object1Geo: The object1's geocentric vector in kilometers.
    ///   - object2Geo: The object1's geocentric vector in kilometers.
    public static func hasLineOfSight(object1Geo: Vector, object2Geo: Vector) -> Bool {
        let τ_min = (object1Geo.magnitudeSquared() - dotProduct(object1Geo, object2Geo))
            / ((object1Geo.magnitudeSquared() + object2Geo.magnitudeSquared()) - 2 * dotProduct(object1Geo, object2Geo))
        if τ_min < 0 || τ_min > 1 {
            return true
        }

        return (1 - τ_min) * object1Geo.magnitudeSquared() + dotProduct(object1Geo, object2Geo) * τ_min >= EarthConstants.Rₑ * EarthConstants.Rₑ
    }

    /// Calculate the air mass given a true zenith angle.
    ///
    /// Zenith angle should be in radians.
    /// This formula is adopted from [Young (1994)](http://www.opticsinfobase.org/abstract.cfm?id=41471).
    /// - Seealso: https://en.wikipedia.org/wiki/Air_mass_(astronomy)
    /// - Parameter zenithAngle: The zenith angle in radians.
    /// - Returns: The air mass number.
    public static func airMass(zenithAngle: Double) -> Double {
        let divisor = 1.002432 * pow(cos(zenithAngle), 2) + 0.148386 * cos(zenithAngle) + 0.0096467
        let dividend = pow(cos(zenithAngle), 3) + 0.149864 * pow(cos(zenithAngle), 2) + 0.0102963 *
        cos(zenithAngle) + 0.000303978
        return divisor / dividend
    }

    /// The angle between the sun, the target and observer.
    /// - Parameters:
    ///   - targetPosition: The target position in ECI frame.
    ///   - sunPosition: The sun position in ECI frame.
    ///   - observerPosition: The observer position in ECI frame.
    /// - Returns: The phase angle between the sun, the target and observer.
    public static func phaseAngle(
        targetPosition: Vector,
        sunPosition: Vector,
        observerPosition: Vector
    ) -> Double {
        let bodyObserverDist = (targetPosition - observerPosition).magnitude()
        let sunObserverDist = (sunPosition - observerPosition).magnitude()
        let sunBodyDist = (targetPosition - sunPosition).magnitude()
        let cosPhaseAngle = (bodyObserverDist * bodyObserverDist + sunBodyDist * sunBodyDist - sunObserverDist * sunObserverDist) / (2 * bodyObserverDist * sunBodyDist)
        return acos(cosPhaseAngle)
    }

    /// Calculate the visual magnitude of a satellite given its intrinsic magnitude, julian date and observer.
    ///
    /// - SeeAlso: https://astronomy.stackexchange.com/a/28765/15972
    /// - Parameters:
    ///   - instrinsicMagnitude: The intrinsic magnitude of a satellite. Data source may include QSMag.
    ///   - range: The distance from the satellite to the observer, in kilometers.
    ///   - phaseAngle: The phase angle between the sun, the target and observer, in radians.
    ///   - zenithAngle: The angle of the satellite and zenith, in radians.
    /// - Returns: The visual magnitude of a satellite.
    public static func satelliteMagnitude(
        instrinsicMagnitude: Double,
        range: Double,
        phaseAngle: Double,
        zenithAngle: Double
    ) -> Double {
        let phaseAngleTerm = sin(phaseAngle) + (.pi - phaseAngle) * cos(phaseAngle)
        let atmoTerm = 0.12 * airMass(zenithAngle: zenithAngle)
        return instrinsicMagnitude + 5 * log10(range / 1000) - 2.5 * log10(phaseAngleTerm) + atmoTerm
    }

    /// Caculate the object's brightness by assuming the shape as a Lambertian (diffusely-reflecting) sphere.
    ///
    /// We can use the radar cross section area as the cross section area in the calculation.
    ///
    /// - SeeAlso: https://amostech.com/TechnicalPapers/2013/POSTER/COGNION.pdf
    /// - Parameters:
    ///   - crossSectionArea: The cross section area of the object.
    ///   - phaseAngle: The phase angle between the sun, the target and observer, in radians.
    ///   - albedo: The percentage of light reflected from the surface, a number between 0 and 1.
    ///   - range: The distance between the object and the observer, in meters.
    /// - Returns: The brightness in visual magitude.
    public static func lambertianSphereMagnitude(
        crossSectionArea: Double,
        range: Double,
        phaseAngle: Double,
        albedo: Double
    ) -> Double {
        let satelliteRadius = sqrt(crossSectionArea / .pi)
        let phaseTerm = sin(phaseAngle) + (.pi - phaseAngle) * cos(phaseAngle)
        let phaseFunction = 2 / 3 * albedo * satelliteRadius * satelliteRadius / (.pi * range * range) * phaseTerm
        return -26.74 - 2.5 * log10(phaseFunction)
    }

    /// <#Description#>
    ///
    /// - SeeAlso: https://arxiv.org/pdf/2003.07805.pdf
    /// - Parameters:
    ///   - baseMagnitude: <#baseMagnitude description#>
    ///   - cosGeoSatObserverAngle: <#projectedProfile description#>
    ///   - range: <#range description#>
    ///   - sunCoordinate: <#sunCoordinate description#>
    ///   - satelliteCoordinate: <#satelliteCoordinate description#>
    /// - Returns: <#description#>
    public static func starLinkMagnitude(
        baseMagnitude: Double = 4.1,
        cosGeoSatObserverAngle: Double,
        range: Double,
        sunCoordinate: RADec,
        satelliteCoordinate: RADec
    ) -> Double {
        //  The satellite's flat side is proportional to the cosine of the angle between the direction to the Sun and the perpendicular to the plane of that side
        let solarAspect = sin(sunCoordinate.dec) * sin(satelliteCoordinate.dec) + cos(sunCoordinate.dec) * cos(satelliteCoordinate.dec) * cos(sunCoordinate.ra - satelliteCoordinate.ra)
        let term = cosGeoSatObserverAngle / range / range
        return baseMagnitude - 2.5 * log10(-term * solarAspect)
    }
}
