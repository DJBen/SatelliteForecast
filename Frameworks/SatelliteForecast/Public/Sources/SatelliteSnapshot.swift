//
//  SatelliteSnapshot.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/2/21.
//

import Foundation
@preconcurrency import SatelliteKit

/// A snapshot of the satellite of a specific date, coordinate, velocity and whether
/// if it is illuminated by sunlight.
public struct SatelliteSnapshot: Sendable {
    public let julianDate: Double
    public let position: AziEleDst
    /// Distance between the observer and the satellite, in km.
    public let distance: Double
    public let isIlluminated: Bool

    /// The sun's elevation, ranging from -90 to 90 degrees.
    public let sunElevation: Double
    /// The sun-satellite-observer angle, in radians.
    public let phaseAngle: Double
    /// A best effort estimation of the visual magnitude of the satellite. `nil` if not available.
    public let visualMagnitude: Double?

    public init(
        julianDate: Double,
        position: AziEleDst,
        distance: Double,
        isIlluminated: Bool,
        sunElevation: Double,
        phaseAngle: Double,
        visualMagnitude: Double?
    ) {
        self.julianDate = julianDate
        self.position = position
        self.distance = distance
        self.isIlluminated = isIlluminated
        self.sunElevation = sunElevation
        self.phaseAngle = phaseAngle
        self.visualMagnitude = visualMagnitude
    }
}

extension SatelliteSnapshot: Equatable {}

extension SatelliteSnapshot: Hashable {}

extension SatelliteSnapshot: Codable {}

public struct SnapshotsAroundPass: Equatable, Sendable {
    public let first: SatelliteSnapshot
    public let second: SatelliteSnapshot

    public init(
        first: SatelliteSnapshot,
        second: SatelliteSnapshot
    ) {
        self.first = first
        self.second = second
    }
}

extension SnapshotsAroundPass: Codable {}

public struct NotableSnapshots: Equatable, Sendable {
    public let rise: SnapshotsAroundPass
    public let transit: SnapshotsAroundPass
    public let set: SnapshotsAroundPass

    public struct IlluminationChangeAndSnapshots: Equatable, Codable, Sendable {
        public let change: Pass.Illumination.Change
        public let snapshots: SnapshotsAroundPass

        public init(change: Pass.Illumination.Change, snapshots: SnapshotsAroundPass) {
            self.change = change
            self.snapshots = snapshots
        }
    }

    public let illuminationChanges: [IlluminationChangeAndSnapshots]
    
    public var exitsShadow: SnapshotsAroundPass? {
        illuminationChanges.first {
            if case .exitsShadow(_) = $0.change {
                true
            } else {
                false
            }
        }?.snapshots
    }
    
    public var entersShadow: SnapshotsAroundPass? {
        illuminationChanges.first {
            if case .entersShadow(_) = $0.change {
                true
            } else {
                false
            }
        }?.snapshots
    }
    
    /// The highest elevation at which the satellite is illuminated during the pass.
    /// If the transit point is illuminated, this is the transit elevation.
    /// Otherwise, it's the maximum elevation from rise, set, and illumination change points.
    /// Returns -1 if no illuminated points are found or sun elevation is too high (> -6).
    public var visibleCulminationElevation: Double {
        if transit.first.sunElevation > -6 {
            return -1
        }
        
        // If transit is illuminated, use its elevation
        if transit.first.isIlluminated || transit.second.isIlluminated {
            return max(transit.first.position.elev, transit.second.position.elev)
        }
        
        // Start with -1 as default
        var maxElevation: Double = -1
        
        // Check rise elevation if illuminated
        if rise.first.isIlluminated || rise.second.isIlluminated {
            maxElevation = max(maxElevation, max(rise.first.position.elev, rise.second.position.elev))
        }
        
        // Check set elevation if illuminated
        if set.first.isIlluminated || set.second.isIlluminated {
            maxElevation = max(maxElevation, max(set.first.position.elev, set.second.position.elev))
        }
        
        // Check all illumination changes
        for change in illuminationChanges {
            maxElevation = max(maxElevation,
                               max(change.snapshots.first.position.elev,
                                   change.snapshots.second.position.elev))
        }
        
        return maxElevation
    }

    public init(
        rise: SnapshotsAroundPass,
        transit: SnapshotsAroundPass,
        set: SnapshotsAroundPass,
        illuminationChanges: [NotableSnapshots.IlluminationChangeAndSnapshots]
    ) {
        self.rise = rise
        self.transit = transit
        self.set = set
        self.illuminationChanges = illuminationChanges
    }
}

extension NotableSnapshots: Codable {}

public struct PassSnapshots: Equatable, Codable, Sendable, CustomDebugStringConvertible {
    public let pass: Pass
    public let snapshots: [SatelliteSnapshot]
    public let notableSnapshots: NotableSnapshots

    public init(
        pass: Pass,
        snapshots: [SatelliteSnapshot],
        notableSnapshots: NotableSnapshots
    ) {
        self.pass = pass
        self.snapshots = snapshots
        self.notableSnapshots = notableSnapshots
    }
    
    public var debugDescription: String {
        "PassSnapshots(pass: \(pass))"
    }
}
