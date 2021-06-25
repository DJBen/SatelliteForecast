//
//  SatelliteInfo.swift
//  SatelliteForcastCore
//
//  Created by Ben Lu on 6/23/21.
//

import Foundation
import SatelliteKit
import SatelliteCatalog

public struct SatelliteInfo {
    public let noradIndex: Int

    public let satellite: Satellite
    public let satCat: SatCat?
    public let ucsSat: UCSSat?

    public init(
        noradIndex: Int,
        satellite: Satellite,
        satCat: SatCat? = nil,
        ucsSat: UCSSat? = nil
    ) {
        self.satellite = satellite
        self.noradIndex = Int(satellite.noradIdent)!
        self.satCat = satCat
        self.ucsSat = ucsSat
    }
}

extension SatelliteInfo: Equatable {}
