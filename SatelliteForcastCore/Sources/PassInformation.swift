//
//  PassInformation.swift
//  SatelliteForcastCore
//
//  Created by Ben Lu on 6/7/21.
//

import Foundation
import BTree

/// The information for a single satellite pass.
public struct PassInformation {
    public enum IlluminationChange {
        case entersShadow(date: Date)
        case exitsShadow(date: Date)
    }

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
    public let hightestElevation: DateElev
    
    /// Changes in satellite illumination.
    public let illuminationChanges: [IlluminationChange]
}

extension PassInformation: Equatable {}
extension PassInformation.IlluminationChange: Equatable {}
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
