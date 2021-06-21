//
//  Satellite+Convenience.swift
//  SatelliteForcastCore
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

    /// Construct a snapshot of the satellite given a date and observer coordinate.
    /// - Parameters:
    ///   - date: The date.
    ///   - observer: The observer coordinate in latitude, longitude and altitude.
    public func snapshot(
        date: Date,
        observer: LatLonAlt
    ) -> SatelliteSnapshot {
        return snapshot(julianDate: date.julianDate, observer: observer)
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
    ) -> Map<Double, SatelliteSnapshot> {
        var snapshots = Map<Double, SatelliteSnapshot>()
        stride(
            from: julianDateRange.lowerBound,
            // Append interval to overshoot the upperBound and make sure it is included.
            through: julianDateRange.upperBound + interval * TimeConstants.sec2day,
            by: interval * TimeConstants.sec2day
        )
        .forEach { (julianDate) in
            snapshots[julianDate] = snapshot(julianDate: julianDate, observer: observer)
        }
        return snapshots
    }

    private func generatePassInfo(
        noradIndex: Int,
        observer: LatLonAlt,
        julianDateRange: Range<Double>,
        fineInterval: TimeInterval = 3
    ) -> (pass: PassInformation, snapshots: Map<Double, SatelliteSnapshot>) {
        let fineSnapshots = snapshots(
            observer: observer,
            julianDateRange: julianDateRange,
            interval: fineInterval
        )

        // Use a cheaper quadratic interpolation to find RST times.
        let elevInterp = quadraticInterpolate(fineSnapshots.map { ($0.0, $0.1.position.elev) }, steps: 3000)
        let maxElevPair = elevInterp.max(by: { $0.1 < $1.1 })!
        let risesAtPair: (Double, Double)? = {
            for index in elevInterp.indices where index < elevInterp.index(before: elevInterp.endIndex) {
                if elevInterp[index].1 <= 0 && elevInterp[elevInterp.index(after: index)].1 > 0 {
                    return elevInterp[elevInterp.index(after: index)]
                }
            }
            return nil
        }()
        let setsAtPair: (Double, Double)? = {
            for index in elevInterp.indices where index < elevInterp.index(before: elevInterp.endIndex) {
                if elevInterp[index].1 > 0 && elevInterp[elevInterp.index(after: index)].1 <= 0 {
                    return elevInterp[elevInterp.index(after: index)]
                }
            }
            return nil
        }()

        var illuminationChanges = [PassInformation.Illumination.Change]()

        for index in fineSnapshots.indices where index < fineSnapshots.index(before: fineSnapshots.endIndex) {
            let snapshot1 = fineSnapshots[index].1
            let snapshot2 = fineSnapshots[fineSnapshots.index(after: index)].1

            if snapshot1.isIlluminated && !snapshot2.isIlluminated {
                illuminationChanges.append(.entersShadow(julianDate: snapshot2.julianDate))
            } else if !snapshot1.isIlluminated && snapshot2.isIlluminated {
                illuminationChanges.append(.exitsShadow(julianDate: snapshot2.julianDate))
            }
        }

        let sunElev = azel(
            julianDate: maxElevPair.0,
            site: (observer.lat, observer.lon),
            cele: solarGeo(julianDays: maxElevPair.0)
        ).alt

        let pass = PassInformation(
            noradIndex: noradIndex,
            rise: risesAtPair.map { PassInformation.DateElev(julianDate: $0.0, elev: $0.1) }!,
            set: setsAtPair.map { PassInformation.DateElev(julianDate: $0.0, elev: $0.1) }!,
            transit: PassInformation.DateElev(
                julianDate: maxElevPair.0, elev: maxElevPair.1
            ),
            illumination: PassInformation.Illumination(
                initiallyIlluminated: fineSnapshots.first!.1.isIlluminated,
                changes: illuminationChanges
            ),
            sunElevationAtTransit: sunElev
        )

        return (pass: pass, snapshots: fineSnapshots)
    }

    /// Find satellite passes over a large time span.
    ///
    /// The search uses a coarse step first to find any window where the satellite is above horizon, than it employs finer steps
    /// over the candidate time span to generate detailed satellite ephemerides of that mentioned pass.
    /// - Parameters:
    ///   - observer: The observer corodinate.
    ///   - coarseSnapshots: Coarse snapshots to find satellite passes.
    ///   - DatePosition: The min elevation required for the pass to be considered valid.
    ///   - fineInterval: The fine interval in which the ephemerides and detailed pass info are generated.
    /// - Returns: A tuple containing the following:
    ///   - passes: A list of satellite passes.
    ///   - snapshots: Resulting snapshots by merging the coarse snapshots and the generated fine snapshots.
    public func findPasses(
        noradIndex: Int,
        observer: LatLonAlt,
        coarseSnapshots: Map<Double, SatelliteSnapshot>,
        minElevation: Double = 10,
        fineInterval: TimeInterval = 3
    ) -> (passes: [PassInformation], snapshots: Map<Double, SatelliteSnapshot>) {
        var snapshotBeforeRising: SatelliteSnapshot?
        var snapshotAfterSetting: SatelliteSnapshot?
        var passes = [PassInformation]()
        var resultSnapshots = coarseSnapshots

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
                let (pass, snapshots) = generatePassInfo(
                    noradIndex: noradIndex,
                    observer: observer,
                    julianDateRange: fromDate..<toDate,
                    fineInterval: fineInterval
                )

                if pass.transit.elev >= minElevation {
                    passes.append(pass)
                    resultSnapshots = resultSnapshots.merging(snapshots)
                }

                snapshotBeforeRising = nil
                snapshotAfterSetting = nil
            }
        }
        return (passes, resultSnapshots)
    }
}
