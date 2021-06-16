//
//  PassInformation.swift
//  SatelliteForcastCore
//
//  Created by Ben Lu on 6/7/21.
//

import Foundation
import BTree

/// `PassInformation` is a summary of the physical characteristics about a satellite pass, including the times of rise, set, transit
/// (point of higest elevation), any changes in illumination, and the elevation of the sun at transit.
/// We can derive the visibility of the pass by combining these attributes together.
public struct PassInformation {
    public struct DateElev {
        public let julianDate: Double
        public let elev: Double
    }

    /// The time and elevation when satellite rises above the horizon.
    /// At least one of `rise` and `set` must exist.
    public let rise: DateElev
    /// The time when satellite sets below the horizon.
    /// At least one of `rise` and `set` must exist.
    public let set: DateElev

    /// The time and elelvation angle (in degrees) of the highest elevation point during the pass.
    public let transit: DateElev

    public struct Illumination {
        public enum Change {
            case entersShadow(julianDate: Double)
            case exitsShadow(julianDate: Double)
        }

        public let initiallyIlluminated: Bool
        public let changes: [Change]

        /// Whether any part of the pass is illuminated.
        public var hasAnyIllumination: Bool {
            func hasExitsShadow(_ changes: Change) -> Bool {
                switch changes {
                case .exitsShadow(julianDate: _):
                    return true
                default:
                    return false
                }
            }
            return initiallyIlluminated || changes.contains { hasExitsShadow($0) }
        }
    }

    /// The satellite illumination ifnformation.
    public let illumination: Illumination

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

    public var visibility: Visibility {
        if sunElevationAtTransit > -6 {
            return .daylight
        }

        if illumination.hasAnyIllumination {
            return .visible
        } else {
            return .unlit
        }
    }
}

extension PassInformation: Equatable {}
extension PassInformation.Illumination: Equatable {}
extension PassInformation.Illumination.Change: Equatable {}
extension PassInformation.Visibility: Equatable {}
extension PassInformation.DateElev: Equatable {}
