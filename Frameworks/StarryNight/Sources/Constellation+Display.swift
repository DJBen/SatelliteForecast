//
//  Constellation+Display.swift
//  Graviton
//
//  Created by Sihao Lu on 3/4/17.
//  Copyright © 2017 Ben Lu. All rights reserved.
//

import Foundation
import CoreGraphics
import SQLite
@preconcurrency import SatelliteKit

extension StarManager {
    public func displayCenter(for constellation: Constellation) -> Vector? {
        return constellationCenter[constellation.iAUName]
    }

    public func displayCenters(for constellations: [Constellation]) async -> [Constellation: Vector] {
        var result = [Constellation: Vector]()
        for constellation in constellations {
            if constellation.iAUName == "Ser1" || constellation.iAUName == "Ser2" || constellation.iAUName == "Ser" {
                result[self.constellation(iau: "Ser1")!] = constellationCenter["Ser1"]!
                result[self.constellation(iau: "Ser2")!] = constellationCenter["Ser2"]!
            } else {
                result[constellation] = constellationCenter[constellation.iAUName]!
            }
        }
        return result
    }
}
