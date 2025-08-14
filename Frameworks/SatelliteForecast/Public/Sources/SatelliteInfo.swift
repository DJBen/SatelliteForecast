//
//  SatelliteInfo.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/23/21.
//

import Foundation
import QSMag
@preconcurrency import SatelliteKit
import SatelliteCatalog

public struct SatelliteInfo: Sendable {
    public let elements: Elements
    public let satCat: SatCat?
    public let ucsSat: UCSSat?
    public let qsMag: QSMag?

    public init(
        elements: Elements,
        satCat: SatCat? = nil,
        ucsSat: UCSSat? = nil,
        qsMag: QSMag? = nil
    ) {
        self.elements = elements
        self.satCat = satCat
        self.ucsSat = ucsSat
        self.qsMag = qsMag
    }

    public var noradIndex: UInt {
        elements.noradIndex
    }
}

extension SatelliteInfo: Equatable {}
