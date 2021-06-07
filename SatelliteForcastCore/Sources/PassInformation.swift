//
//  PassInformation.swift
//  SatelliteForcastCore
//
//  Created by Ben Lu on 6/7/21.
//

import Foundation

/// The information for a single satellite pass.
public struct PassInformation {
    public enum IlluminationChange {
        case entersShadow(date: Date)
        case exitsShadow(date: Date)
    }

    /// The time when satellite rises above the horizon. Might be `nil` if the satellite starts above horizon.
    public let risesAt: Date?
    /// The time when satellite sets below the horizon. Might be `nil` if the satellite never sets.
    public let setsAt: Date?
    /// Changes in satellite illumination.
    public let illuminationChanges: [IlluminationChange]
    /// Snapshots of the satellites consisting of
    public let snapshots: [SatelliteSnapshot]
}

extension PassInformation: Equatable {}
extension PassInformation.IlluminationChange: Equatable {}
