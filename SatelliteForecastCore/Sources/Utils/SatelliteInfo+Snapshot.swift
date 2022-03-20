//
//  Elements+Snapshot.swift
//  SatelliteForecastCore
//
//  Created by Ben Lu on 6/4/21.
//

import BTree
import Foundation
import QSMag
import SatelliteKit
import SolarSystem
import VSOP87

extension SatelliteSnapshot {
    public init(
        satelliteInfo: SatelliteInfo,
        julianDate: Double,
        observer: LatLonAlt
    ) throws {
        let elements = satelliteInfo.elements
        let satellite = Satellite(withTLE: elements)
        let eciPosition = try satellite.position(julianDays: julianDate)
        let obsCel = geo2eci(julianDays: julianDate, geodetic: observer)

        func topVector2AziEleDst(_ top: Vector) -> AziEleDst {
            let z = top.magnitude()

            return AziEleDst(
                azim: atan2pi(top.y, -top.x) * rad2deg,
                elev: asin(top.z / z) * rad2deg,
                dist: z
            )
        }
        let position = topVector2AziEleDst(
            cel2top(julianDays: julianDate, satCel: eciPosition, obsCel: obsCel)
        )
        let solarCel = solarCel(julianDays: julianDate)
        let isIlluminated = AstroAlgorithms.hasLineOfSight(
            object1Geo: eciPosition,
            object2Geo: solarCel * au2Km
        )
        let phaseAngle = AstroAlgorithms.phaseAngle(
            targetPosition: eciPosition,
            sunPosition: solarCel,
            observerPosition: obsCel
        )
        let sunElev = azel(
            julianDate: julianDate,
            site: (observer.lat, observer.lon),
            cele: cartesianToRaDec(solarCel)
        ).elev
        let visualMagnitude: Double?
        if let crossSectionArea = satelliteInfo.satCat?.rcs {
            visualMagnitude = AstroAlgorithms.lambertianSphereMagnitude(
                crossSectionArea: crossSectionArea,
                range: position.dist * 1000,
                phaseAngle: phaseAngle,
                albedo: 0.25
            )
        } else {
            visualMagnitude = nil
        }

        self.init(
            julianDate: julianDate,
            position: position,
            isIlluminated: isIlluminated,
            sunElevation: sunElev,
            phaseAngle: phaseAngle,
            visualMagnitude: visualMagnitude
        )
    }
}

extension SatelliteInfo {
    /// Construct a snapshot of the satellite given a date and observer coordinate.
    /// - Parameters:
    ///   - julianDate: The julian date.
    ///   - observer: The observer coordinate in latitude, longitude and altitude.
    public func generateSnapshot(
        julianDate: Double,
        observer: LatLonAlt
    ) throws -> SatelliteSnapshot {
        return try SatelliteSnapshot(
            satelliteInfo: self,
            julianDate: julianDate,
            observer: observer
        )
    }

    /// Generate satellite snapshots over a date range with a given interval at an observer location.
    /// - Parameters:
    ///   - observer: Observer coordinate.
    ///   - dateRange: The date range to generate satellite ephemerides.
    ///   - interval: The interval to generate satellite ephemerides.
    /// - Returns: A list of satellite snapshots over a date range with a given interval at an observer location in chronological order.
    public func generateSnapshots(
        observer: LatLonAlt,
        julianDateRange: ClosedRange<Double>,
        interval: TimeInterval = 30
    ) throws -> [SatelliteSnapshot] {
        return try stride(
            from: julianDateRange.lowerBound,
            // Append interval to overshoot the upperBound and make sure it is included.
            through: julianDateRange.upperBound + interval * TimeConstants.sec2day,
            by: interval * TimeConstants.sec2day
        )
        .map { (julianDate) in
            try generateSnapshot(
                julianDate: julianDate,
                observer: observer
            )
        }
    }

    private func generatePassInfo(
        noradIndex: UInt,
        observer: LatLonAlt,
        julianDateRange: ClosedRange<Double>,
        fineInterval: TimeInterval = 3
    ) throws -> PassSnapshots {
        let fineSnapshots = try generateSnapshots(
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
            let snapshot1 = fineSnapshots[index]
            let snapshot2 = fineSnapshots[fineSnapshots.index(after: index)]

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

        let sunElev = SolarSystemBody.sun.aziEle(
            julianDay: maxElevDatePos.julianDate,
            observer: observer
        ).elev

        let pass = Pass(
            noradIndex: noradIndex,
            rise: riseDatePos,
            set: setDatePos,
            transit: maxElevDatePos,
            illumination: Pass.Illumination(
                initiallyIlluminated: fineSnapshots.first!.isIlluminated,
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
        observer: LatLonAlt,
        coarseSnapshots: [SatelliteSnapshot],
        qsMag: QSMag? = nil,
        crossSectionArea: Double? = nil,
        minElevation: Double = 10,
        fineInterval: TimeInterval = 3
    ) throws -> [PassSnapshots] {
        var snapshotBeforeRising: SatelliteSnapshot?
        var snapshotAfterSetting: SatelliteSnapshot?
        var passSnapshotsList = [PassSnapshots]()

        for index in coarseSnapshots.indices where index < coarseSnapshots.index(before: coarseSnapshots.endIndex) {
            let snapshot1 = coarseSnapshots[index]
            let snapshot2 = coarseSnapshots[coarseSnapshots.index(after: index)]
            
            precondition(snapshot2.julianDate > snapshot1.julianDate)

            if snapshot1.position.elev <= 0 && snapshot2.position.elev > 0 {
                snapshotBeforeRising = snapshot1
            }

            if snapshot1.position.elev > 0 && snapshot2.position.elev <= 0 {
                snapshotAfterSetting = snapshot2
            }

            if let fromDate = snapshotBeforeRising?.julianDate, let toDate = snapshotAfterSetting?.julianDate, fromDate < toDate {
                let passSnapshots = try generatePassInfo(
                    noradIndex: elements.noradIndex,
                    observer: observer,
                    julianDateRange: fromDate...toDate,
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
