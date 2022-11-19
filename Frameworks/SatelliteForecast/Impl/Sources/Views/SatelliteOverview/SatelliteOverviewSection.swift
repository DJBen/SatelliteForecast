//
//  SatelliteOverviewSection.swift
//  SatelliteOverviewSection
//
//  Created by Ben Lu on 7/31/21.
//

import Foundation
import SatelliteForecast

public enum SatelliteOverviewSection: Equatable, Hashable {
    case satellitesOfSpecialInterest([SatellitesOfSpecialInterest])
    case categories([SatelliteCategory])
}

public struct SatellitesOfSpecialInterest: ExpressibleByIntegerLiteral, Equatable, Hashable, Codable {
    public typealias IntegerLiteralType = Int

    static let iss: SatellitesOfSpecialInterest = 25544
    static let tianhe: SatellitesOfSpecialInterest = 48274

    public let noradIndex: UInt

    public init(noradIndex: UInt) {
        self.noradIndex = noradIndex
    }

    public init(integerLiteral value: Int) {
        self.noradIndex = UInt(value)
    }
}
