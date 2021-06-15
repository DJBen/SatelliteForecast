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
        public let date: Date
        public let elev: Double
    }

    /// The time and elevation when satellite rises above the horizon. Might be `nil` if the satellite starts above horizon.
    /// At least one of `rise` and `set` must exist.
    public let rise: DateElev?
    /// The time when satellite sets below the horizon. Might be `nil` if the satellite never sets.
    /// At least one of `rise` and `set` must exist.
    public let set: DateElev?

    /// The time when satellite rises above the horizon. Might be `nil` if the satellite starts above horizon.
    /// At least one of `risesAt` and `setsAt` must exist.
    public var risesAt: Date? {
        rise?.date
    }
    /// The time when satellite sets below the horizon. Might be `nil` if the satellite never sets.
    /// At least one of `risesAt` and `setsAt` must exist.
    public var setsAt: Date? {
        `set`?.date
    }

    /// The time and elelvation angle (in degrees) of the highest elevation point during the pass.
    public let transit: DateElev

    public struct Illumination {
        public enum Change {
            case entersShadow(date: Date)
            case exitsShadow(date: Date)
        }

        public let initiallyIlluminated: Bool
        public let changes: [Change]

        /// Whether any part of the pass is illuminated.
        public var hasAnyIllumination: Bool {
            func hasExitsShadow(_ changes: Change) -> Bool {
                switch changes {
                case .exitsShadow(date: _):
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
}

extension PassInformation: Equatable {}
extension PassInformation.Illumination: Equatable {}
extension PassInformation.Illumination.Change: Equatable {}
extension PassInformation.DateElev: Equatable {}

extension Map where Key == Date, Value == SatelliteSnapshot {
    public subscript(pass: PassInformation) -> Map<Key, Value> {
        if let risesAt = pass.risesAt, let setsAt = pass.setsAt {
            return submap(from: risesAt, through: setsAt)
        } else if let risesAt = pass.risesAt {
            return submap(from: risesAt, through: self[index(before: endIndex)].0)
        } else if let setsAt = pass.setsAt {
            return submap(from: self[startIndex].0, through: setsAt)
        } else {
            fatalError("Pass must have a rise and set value")
        }
    }
}
