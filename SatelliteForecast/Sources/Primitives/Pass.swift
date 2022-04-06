//
//  Pass.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/7/21.
//

import Foundation
import BTree

/// `Pass` is a summary of the physical characteristics about a satellite pass, including the times of rise, set, transit
/// (point of higest elevation), any changes in illumination, and the elevation of the sun at transit.
/// We can derive the visibility of the pass by combining these attributes together.
public struct Pass {
    public let noradIndex: UInt
    
    public struct DatePosition {
        public let julianDate: Double
        public let azim: Double
        public let elev: Double

        public init(julianDate: Double, azim: Double, elev: Double) {
            self.julianDate = julianDate
            self.azim = azim
            self.elev = elev
        }
    }

    /// The time and elevation when satellite rises above the horizon.
    ///
    /// At least one of `rise` and `set` must exist.
    public let rise: DatePosition
    
    /// The time and elevation when satellite sets below the horizon.
    ///
    /// At least one of `rise` and `set` must exist.
    public let set: DatePosition
    
    /// The time and elelvation angle (in degrees) of the highest elevation point during the pass.
    ///
    /// Note that the transit point is not always illuminated. Use `highestIlluminatedElevation` to get the highest illuminated elevation.
    public let transit: DatePosition

    /// The highest illuminated elevation, in degrees.
    public var highestIlluminatedElevation: Double {
        if illumination.changes.isEmpty {
            if illumination.initiallyIlluminated {
                return transit.elev
            } else {
                return 0
            }
        } else {
            var highest: Double = 0
            var lastPointIlluminated = illumination.initiallyIlluminated
            var lastIlluminationStartJulianDate: Double? = illumination.initiallyIlluminated ? rise.julianDate : nil

            for change in illumination.changes {
                switch change {
                case let .exitsShadow(datePosition):
                    highest = max(highest, datePosition.elev)
                    lastIlluminationStartJulianDate = datePosition.julianDate
                    lastPointIlluminated = true
                case let .entersShadow(datePosition):
                    if let lastIlluminationStartJulianDate = lastIlluminationStartJulianDate,
                       lastIlluminationStartJulianDate < transit.julianDate && datePosition.julianDate >= transit.julianDate {
                        highest = transit.elev
                    } else {
                        highest = max(highest, datePosition.elev)
                    }
                    lastPointIlluminated = false
                }
            }

            if lastPointIlluminated, let lastIlluminationStartJulianDate = lastIlluminationStartJulianDate, lastIlluminationStartJulianDate < transit.julianDate {
                highest = transit.elev
            }

            return highest
        }
    }
    
    public struct Illumination {
        public enum Change {
            case entersShadow(DatePosition)
            case exitsShadow(DatePosition)

            public var datePosition: DatePosition {
                switch self {
                case let .entersShadow(datePosition),
                    let .exitsShadow(datePosition):
                    return datePosition
                }
            }
        }

        public let initiallyIlluminated: Bool
        public let changes: [Change]

        public init(initiallyIlluminated: Bool, changes: [Pass.Illumination.Change]) {
            self.initiallyIlluminated = initiallyIlluminated
            self.changes = changes
        }
    }

    /// The satellite illumination ifnformation.
    public let illumination: Illumination

    /// Whether any part of the pass above a certain elevation is illuminated.
    public func hasAnyIllumination(aboveElevation elev: Double = 10) -> Bool {
        return highestIlluminatedElevation >= elev
    }

    /// The elevation of the sun at transit. A satellite pass can usually only be seen after civil twilight or before civil dawn when sun is
    /// below -6 degrees.
    public let sunElevationAtTransit: Double

    /// The visibility of the satellite pass.
    public enum Visibility {
        /// At least a part of the pass is lit, and the sun elevation is below -6 degrees (civil twilight / dawn point).
        case visible
        /// Pass happens while sun is up (above -6 degrees). It would be too bright to see the satellite.
        case daylight
        /// Pass happens entirely unlit by the sun.
        case unlit
    }

    /// The visibility of the pass.
    /// A visible pass must satisfy these criteria.
    /// 1. Sun eleavtion is below -6 degrees (civil dawn / twilight)
    /// 2. Has any illumination above 10 degrees above horizon.
    /// If 1) is not satisfied, the visibility is *daylight*; if 2) is not satisfied, the visibility is *unlit*.
    public var visibility: Visibility {
        if sunElevationAtTransit > -6 {
            return .daylight
        }

        if hasAnyIllumination() {
            return .visible
        } else {
            return .unlit
        }
    }

    public init(
        noradIndex: UInt,
        rise: Pass.DatePosition,
        set: Pass.DatePosition,
        transit: Pass.DatePosition,
        illumination: Pass.Illumination,
        sunElevationAtTransit: Double
    ) {
        self.noradIndex = noradIndex
        self.rise = rise
        self.set = set
        self.transit = transit
        self.illumination = illumination
        self.sunElevationAtTransit = sunElevationAtTransit
    }
}

extension Pass: Equatable {}
extension Pass.Illumination: Equatable {}
extension Pass.Illumination.Change: Equatable {}
extension Pass.Visibility: Equatable {}
extension Pass.DatePosition: Equatable {}

extension Pass: Hashable {}
extension Pass.Illumination: Hashable {}
extension Pass.Illumination.Change: Hashable {}
extension Pass.Visibility: Hashable {}
extension Pass.DatePosition: Hashable {}

extension Pass: Codable {}
extension Pass.Illumination: Codable {}
extension Pass.Illumination.Change: Codable {}
extension Pass.Visibility: Codable {}
extension Pass.DatePosition: Codable {}
