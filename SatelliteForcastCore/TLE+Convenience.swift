//
//  TLE+Convenience.swift
//  SatelliteForcast
//
//  Created by Ben Lu on 5/30/21.
//

import SatelliteKit

extension TLE {
    public init(raw: String) throws {
        let lines = raw.components(separatedBy: .newlines)
        try self.init(lines[0], lines[1], lines[2])
    }
}

extension TLE: Equatable {
    public static func == (lhs: TLE, rhs: TLE) -> Bool {
        return lhs.commonName == rhs.commonName &&
            lhs.noradIndex == rhs.noradIndex &&
            lhs.launchName == rhs.launchName &&
            lhs.t₀ == rhs.t₀ &&
            lhs.e₀ == rhs.e₀ &&
            lhs.i₀ == rhs.i₀ &&
            lhs.ω₀ == rhs.ω₀ &&
            lhs.Ω₀ == rhs.Ω₀ &&
            lhs.M₀ == rhs.M₀ &&
            lhs.n₀ == rhs.n₀ &&
            lhs.a₀ == rhs.a₀ &&
            lhs.ephemType == rhs.ephemType &&
            lhs.tleClass == rhs.tleClass &&
            lhs.tleNumber == rhs.tleNumber &&
            lhs.revNumber == rhs.revNumber
    }
}
