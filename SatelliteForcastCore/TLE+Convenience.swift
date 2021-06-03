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
