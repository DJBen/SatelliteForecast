//
//  AstroAlgorithms.swift
//  SatelliteForcastCore
//
//  Created by Ben Lu on 6/2/21.
//

import SatelliteKit

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
        let radiusOfEarth: Double = 6378.137
        return (1 - τ_min) * object1Geo.magnitudeSquared() + dotProduct(object1Geo, object2Geo) * τ_min >= radiusOfEarth * radiusOfEarth
    }
}
