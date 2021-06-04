//
//  Satellite+Convenience.swift
//  SatelliteForcastCore
//
//  Created by Ben Lu on 6/4/21.
//

import Foundation
import SatelliteKit

extension Satellite: Equatable {
    public static func == (lhs: Satellite, rhs: Satellite) -> Bool {
        return lhs.tle == rhs.tle &&
            lhs.commonName == rhs.commonName &&
            lhs.noradIdent == rhs.noradIdent &&
            lhs.t₀Days1950 == rhs.t₀Days1950
    }
}
