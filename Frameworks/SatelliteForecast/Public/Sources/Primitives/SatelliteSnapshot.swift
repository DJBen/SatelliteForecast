//
//  SatelliteSnapshot.swift
//  SatelliteForecast
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

extension SnapshotsAroundPass: Codable {}

public struct NotableSnapshots: Equatable {
    public let rise: SnapshotsAroundPass
    public let transit: SnapshotsAroundPass
    public let set: SnapshotsAroundPass

    public struct IlluminationChangeAndSnapshots: Equatable, Codable {
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

extension NotableSnapshots: Codable {
    struct IlluminationChangesPair: Equatable, Codable {
        let timestamp: Double
        let change: NotableSnapshots.IlluminationChangeAndSnapshots

        init(_ pair: (Double, NotableSnapshots.IlluminationChangeAndSnapshots)) {
            self.timestamp = pair.0
            self.change = pair.1
        }
    }

    enum CodingKeys: String, CodingKey {
        case rise
        case transit
        case set
        case illuminationChanges
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rise, forKey: .rise)
        try container.encode(transit, forKey: .transit)
        try container.encode(`set`, forKey: .set)
        try container.encode(illuminationChanges.map(IlluminationChangesPair.init), forKey: .illuminationChanges)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rise = try container.decode(SnapshotsAroundPass.self, forKey: .rise)
        let transit = try container.decode(SnapshotsAroundPass.self, forKey: .transit)
        let `set` = try container.decode(SnapshotsAroundPass.self, forKey: .set)
        let illuminationChangesPairs = try container.decode([IlluminationChangesPair].self, forKey: .illuminationChanges)
        self.init(
            rise: rise,
            transit: transit,
            set: `set`,
            illuminationChanges: BTree<Double, NotableSnapshots.IlluminationChangeAndSnapshots>(
                illuminationChangesPairs.map { ($0.timestamp, $0.change) }
            )
        )
    }
}

public struct PassSnapshots: Equatable, Codable {
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
