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
    public let satellite: Satellite
    public let satCat: SatCat?

    public init(
        satellite: Satellite,
        satCat: SatCat?
    ) {
        self.satellite = satellite
        self.satCat = satCat
    }
}

extension SatelliteInfo: Equatable {}
