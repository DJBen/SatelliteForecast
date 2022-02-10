//
//  Satellite+Convenience.swift
//  SatelliteForecastCore
//
//  Created by Ben Lu on 6/4/21.
//

import BTree
import Foundation
import SatelliteKit

extension Satellite: Equatable {
    public static func == (lhs: Satellite, rhs: Satellite) -> Bool {
        return lhs.tle == rhs.tle &&
            lhs.commonName == rhs.commonName &&
            lhs.noradIdent == rhs.noradIdent &&
            lhs.t₀Days1950 == rhs.t₀Days1950
    }
}

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
    public let snapshots: BTree<Double, SatelliteSnapshot>
    public let notableSnapshots: NotableSnapshots

    public init(
        pass: Pass,
        snapshots: BTree<Double, SatelliteSnapshot>,
        notableSnapshots: NotableSnapshots
    ) {
        self.pass = pass
        self.snapshots = snapshots
        self.notableSnapshots = notableSnapshots
    }
}

extension Satellite {
    /// Construct a snapshot of the satellite given a date and observer coordinate.
    /// - Parameters:
    ///   - julianDate: The julian date.
    ///   - observer: The observer coordinate in latitude, longitude and altitude.
    public func snapshot(
        julianDate: Double,
        observer: LatLonAlt
    ) -> SatelliteSnapshot {
        let eciPosition = position(julianDays: julianDate)
        let obsCel = geo2eci(julianDays: julianDate, geodetic: observer)

        func topVector2AziEleDst(_ top: Vector) -> AziEleDst {
            let z = top.magnitude()

            return AziEleDst(
                azim: atan2pi(top.y, -top.x) * rad2deg,
                elev: asin(top.z / z) * rad2deg,
                dist: z
            )
        }
        let position = topVector2AziEleDst(cel2top(julianDays: julianDate, satCel: eciPosition, obsCel: obsCel))
        let solarCel = solarCel(julianDays: julianDate)
        let isIlluminated = AstroAlgorithms.hasLineOfSight(
            object1Geo: eciPosition,
            object2Geo: solarCel * au2Km
        )
        let (sunElev, _) = azel(
            julianDate: julianDate,
            site: (observer.lat, observer.lon),
            cele: cartesianToRaDec(solarCel)
        )
        return SatelliteSnapshot(
            julianDate: julianDate,
            position: position,
            isIlluminated: isIlluminated,
            sunElevation: sunElev
        )
    }

    /// Generate satellite snapshots over a date range with a given interval at an observer location.
    /// - Parameters:
    ///   - observer: Observer coordinate.
    ///   - dateRange: The date range to generate satellite ephemerides.
    ///   - interval: The interval to generate satellite ephemerides.
    /// - Returns: A list of satellite snapshots over a date range with a given interval at an observer location in chronological order.
    public func snapshots(
        observer: LatLonAlt,
        julianDateRange: Range<Double>,
        interval: TimeInterval = 30
    ) -> BTree<Double, SatelliteSnapshot> {
        var snapshots = BTree<Double, SatelliteSnapshot>()
        stride(
            from: julianDateRange.lowerBound,
            // Append interval to overshoot the upperBound and make sure it is included.
            through: julianDateRange.upperBound + interval * TimeConstants.sec2day,
            by: interval * TimeConstants.sec2day
        )
        .forEach { (julianDate) in
            snapshots.insertOrReplace((julianDate, snapshot(julianDate: julianDate, observer: observer)))
        }
        return snapshots
    }

    private func generatePassInfo(
        noradIndex: Int,
        observer: LatLonAlt,
        julianDateRange: Range<Double>,
        fineInterval: TimeInterval = 3
    ) -> PassSnapshots {
        let fineSnapshots = snapshots(
            observer: observer,
            julianDateRange: julianDateRange,
            interval: fineInterval
        )

        var riseDatePos: Pass.DatePosition!
        var riseSnapshots: SnapshotsAroundPass!
        var setDatePos: Pass.DatePosition!
        var setSnapshots: SnapshotsAroundPass!
        var maxElevDatePos: Pass.DatePosition!
        var transitSnapshots: SnapshotsAroundPass!
        var illuminationChanges = [Pass.Illumination.Change]()
        var illuminationChangesAndSnapshots = BTree<Double, NotableSnapshots.IlluminationChangeAndSnapshots>()

        for index in fineSnapshots.indices where index < fineSnapshots.index(before: fineSnapshots.endIndex) {
            let snapshot1 = fineSnapshots[index].1
            let snapshot2 = fineSnapshots[fineSnapshots.index(after: index)].1

            guard snapshot1.position.elev > 0 || snapshot2.position.elev > 0 else {
                continue
            }

            if snapshot1.position.elev <= 0 && snapshot2.position.elev > 0 {
                riseDatePos = Pass.DatePosition(
                    julianDate: snapshot1.julianDate,
                    azim: snapshot1.position.azim,
                    elev: snapshot1.position.elev
                )
                riseSnapshots = SnapshotsAroundPass(
                    first: snapshot1,
                    second: snapshot2
                )
            }
            if snapshot1.position.elev > 0 && snapshot2.position.elev <= 0 {
                setDatePos = Pass.DatePosition(
                    julianDate: snapshot2.julianDate,
                    azim: snapshot2.position.azim,
                    elev: snapshot2.position.elev
                )
                setSnapshots = SnapshotsAroundPass(
                    first: snapshot1,
                    second: snapshot2
                )
            }
            if maxElevDatePos == nil || maxElevDatePos.elev < snapshot1.position.elev {
                maxElevDatePos = Pass.DatePosition(
                    julianDate: snapshot1.julianDate,
                    azim: snapshot1.position.azim,
                    elev: snapshot1.position.elev
                )
                transitSnapshots = SnapshotsAroundPass(
                    first: snapshot1,
                    second: snapshot2
                )
            }
            if snapshot1.isIlluminated && !snapshot2.isIlluminated {
                let change = Pass.Illumination.Change.entersShadow(Pass.DatePosition(julianDate: snapshot1.julianDate, azim: snapshot1.position.azim, elev: snapshot1.position.elev))
                illuminationChanges.append(change)
                illuminationChangesAndSnapshots.insert(
                    (
                        snapshot1.julianDate,
                        NotableSnapshots.IlluminationChangeAndSnapshots(
                            change: change,
                            snapshots: SnapshotsAroundPass(
                                first: snapshot1,
                                second: snapshot2
                            )
                        )
                    )
                )
            } else if !snapshot1.isIlluminated && snapshot2.isIlluminated {
                let change = Pass.Illumination.Change.exitsShadow(Pass.DatePosition(julianDate: snapshot2.julianDate, azim: snapshot2.position.azim, elev: snapshot2.position.elev))
                illuminationChanges.append(change)
                illuminationChangesAndSnapshots.insert(
                    (
                        snapshot2.julianDate,
                        NotableSnapshots.IlluminationChangeAndSnapshots(
                            change: change,
                            snapshots: SnapshotsAroundPass(
                                first: snapshot1,
                                second: snapshot2
                            )
                        )
                    )
                )
            }
        }

        let sunElev = azel(
            julianDate: maxElevDatePos.julianDate,
            site: (observer.lat, observer.lon),
            cele: solarGeo(julianDays: maxElevDatePos.julianDate)
        ).alt

        let pass = Pass(
            noradIndex: noradIndex,
            rise: riseDatePos,
            set: setDatePos,
            transit: maxElevDatePos,
            illumination: Pass.Illumination(
                initiallyIlluminated: fineSnapshots.first!.1.isIlluminated,
                changes: illuminationChanges
            ),
            sunElevationAtTransit: sunElev
        )

        return PassSnapshots(
            pass: pass,
            snapshots: fineSnapshots,
            notableSnapshots: NotableSnapshots(
                rise: riseSnapshots,
                transit: transitSnapshots,
                set: setSnapshots,
                illuminationChanges: illuminationChangesAndSnapshots
            )
        )
    }

    /// Find satellite passes over a large time span.
    ///
    /// The search uses a coarse step first to find any window where the satellite is above horizon, than it employs finer steps
    /// over the candidate time span to generate detailed satellite ephemerides of that mentioned pass.
    /// - Parameters:
    ///   - observer: The observer corodinate.
    ///   - coarseSnapshots: Coarse snapshots to find satellite passes.
    ///   - minElevation: The min elevation required for the pass to be considered valid.
    ///   - fineInterval: The fine interval in which the ephemerides and detailed pass info are generated.
    /// - Returns: A tuple containing the following:
    ///   - passes: A list of satellite passes.
    ///   - snapshots: Resulting snapshots by merging the coarse snapshots and the generated fine snapshots.
    public func findPasses(
        noradIndex: Int,
        observer: LatLonAlt,
        coarseSnapshots: BTree<Double, SatelliteSnapshot>,
        minElevation: Double = 10,
        fineInterval: TimeInterval = 3
    ) -> [PassSnapshots] {
        var snapshotBeforeRising: SatelliteSnapshot?
        var snapshotAfterSetting: SatelliteSnapshot?
        var passSnapshotsList = [PassSnapshots]()

        for index in coarseSnapshots.indices where index < coarseSnapshots.index(before: coarseSnapshots.endIndex) {
            let snapshot1 = coarseSnapshots[index].1
            let snapshot2 = coarseSnapshots[coarseSnapshots.index(after: index)].1

            if snapshot1.position.elev <= 0 && snapshot2.position.elev > 0 {
                snapshotBeforeRising = snapshot1
            }

            if snapshot1.position.elev > 0 && snapshot2.position.elev <= 0 {
                snapshotAfterSetting = snapshot2
            }

            if let fromDate = snapshotBeforeRising?.julianDate, let toDate = snapshotAfterSetting?.julianDate, fromDate < toDate {
                let passSnapshots = generatePassInfo(
                    noradIndex: noradIndex,
                    observer: observer,
                    julianDateRange: fromDate..<toDate,
                    fineInterval: fineInterval
                )

                if passSnapshots.pass.transit.elev >= minElevation {
                    passSnapshotsList.append(passSnapshots)
                }

                snapshotBeforeRising = nil
                snapshotAfterSetting = nil
            }
        }
        return passSnapshotsList
    }
}
