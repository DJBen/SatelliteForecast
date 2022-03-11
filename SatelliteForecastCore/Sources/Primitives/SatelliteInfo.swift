//
//  SatelliteInfo.swift
//  SatelliteForecastCore
//
//  Created by Ben Lu on 6/23/21.
//

import Foundation
import QSMag
import SatelliteKit
import SatelliteCatalog

public struct SatelliteInfo {
    public let noradIndex: UInt
    public let tle: TLE
    public let satCat: SatCat?
    public let ucsSat: UCSSat?
    public let qsMag: QSMag?

    public init(
        noradIndex: UInt,
        tle: TLE,
        satCat: SatCat? = nil,
        ucsSat: UCSSat? = nil,
        qsMag: QSMag? = nil
    ) {
        self.noradIndex = noradIndex
        self.tle = tle
        self.satCat = satCat
        self.ucsSat = ucsSat
        self.qsMag = qsMag
    }
}

extension SatelliteInfo: Equatable {}

extension SatelliteInfo: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(noradIndex)
        hasher.combine(tle)
    }
}
