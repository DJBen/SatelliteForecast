//
//  SatelliteInfo.swift
//  SatelliteForecastCore
//
//  Created by Ben Lu on 6/23/21.
//

import Foundation
import SatelliteKit
import SatelliteCatalog

public struct SatelliteInfo {
    public let noradIndex: Int
    public let tle: TLE
    public let satCat: SatCat?
    public let ucsSat: UCSSat?

    public init(
        noradIndex: Int,
        tle: TLE,
        satCat: SatCat? = nil,
        ucsSat: UCSSat? = nil
    ) {
        self.noradIndex = noradIndex
        self.tle = tle
        self.satCat = satCat
        self.ucsSat = ucsSat
    }
}

extension SatelliteInfo: Equatable {}
