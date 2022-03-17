//
//  SatelliteSnapshot.swift
//  SatelliteForecastCore
//
//  Created by Ben Lu on 6/2/21.
//

import Foundation
import SatelliteKit
import BTree

/// A snapshot of the satellite of a specific date, coordinate, velocity and whether
/// if it is illuminated by sunlight.
public struct SatelliteSnapshot {
    public let julianDate: Double
    public let position: AziEleDst
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
        isIlluminated: Bool,
        sunElevation: Double,
        phaseAngle: Double,
        visualMagnitude: Double?
    ) {
        self.julianDate = julianDate
        self.position = position
        self.isIlluminated = isIlluminated
        self.sunElevation = sunElevation
        self.phaseAngle = phaseAngle
        self.visualMagnitude = visualMagnitude
    }
}

extension SatelliteSnapshot: Equatable {}

extension SatelliteSnapshot: Hashable {}

public struct SnapshotsAroundPass: Equatable {
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

public struct NotableSnapshots: Equatable {
    public let rise: SnapshotsAroundPass
    public let transit: SnapshotsAroundPass
    public let set: SnapshotsAroundPass

    public struct IlluminationChangeAndSnapshots: Equatable {
        public let change: Pass.Illumination.Change
        public let snapshots: SnapshotsAroundPass

        public init(change: Pass.Illumination.Change, snapshots: SnapshotsAroundPass) {
            self.change = change
            self.snapshots = snapshots
        }
    }

    public let illuminationChanges: BTree<Double, IlluminationChangeAndSnapshots>

    public init(
        rise: SnapshotsAroundPass,
        transit: SnapshotsAroundPass,
        set: SnapshotsAroundPass,
        illuminationChanges: BTree<Double, NotableSnapshots.IlluminationChangeAndSnapshots>
    ) {
        self.rise = rise
        self.transit = transit
        self.set = set
        self.illuminationChanges = illuminationChanges
    }
}

public struct PassSnapshots: Equatable {
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
}
