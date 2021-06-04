//
//  Astronomy+Convenience.swift
//  SatelliteForcastCore
//
//  Created by Ben Lu on 6/4/21.
//

import SatelliteKit

extension LatLonAlt: Equatable {
    public static func == (lhs: LatLonAlt, rhs: LatLonAlt) -> Bool {
        return lhs.lat == rhs.lat &&
            lhs.lon == rhs.lon &&
            lhs.alt == rhs.alt
    }
}

extension AziEleDst: Equatable {
    public static func == (lhs: AziEleDst, rhs: AziEleDst) -> Bool {
        return lhs.azim == rhs.azim &&
            lhs.elev == rhs.elev &&
            lhs.dist == rhs.dist
    }
}
