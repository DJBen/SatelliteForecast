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
            time: Date(julianDate: julianDate),
            site: (observer.lat, observer.lon),
            cele: cartesianToRaDec(solarCel)
        )
        return SatelliteSnapshot(
            date: Date(julianDate: julianDate),
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
        dateRange: Range<Date>,
        interval: TimeInterval = 30
    ) -> Map<Date, SatelliteSnapshot> {
        var snapshots = Map<Date, SatelliteSnapshot>()
        stride(
            from: dateRange.lowerBound.julianDate,
            to: dateRange.upperBound.julianDate,
            by: interval * TimeConstants.sec2day
        )
        .forEach { (julianDate) in
            let date = Date(julianDate: julianDate)
            snapshots[date] = snapshot(julianDate: julianDate, observer: observer)
        }
        return snapshots
    }

    public enum PassFindingParam {
        /// Find satellite passes within a date range, with a coarse search of any moment that the satellite is above the horizon.
        /// If any of these moments are found, it is going to generate the satellite ephemerides with a fine interval for the duration
        /// when satellite is above the horizon.
        case dateRange(
            Range<Date>,
            coarseInterval: TimeInterval = 30,
            fineInterval: TimeInterval = 3
        )

        /// Find satellite passes with a coarse result of satellite ephemerides.
        /// It is going to look for any moments when satellite rises above the horizon. If any of these moments are found, it is going
        /// to generate the satellite ephemerides with a fine interval for that duration.
        case existingSnapshots(
            Map<Date, SatelliteSnapshot>,
            fineInterval: TimeInterval = 3
        )

        var fineInterval: TimeInterval {
            switch self {
            case let .dateRange(_, coarseInterval: _, fineInterval: fineInterval):
                return fineInterval
            case let .existingSnapshots(_, fineInterval: fineInterval):
                return fineInterval
            }
        }
    }

    /// Find satellite passes over a large time span.
    ///
    /// The search uses a coarse step first to find any window where the satellite is above horizon, than it employs finer steps
    /// over the candidate time span to generate detailed satellite ephemerides of that mentioned pass.
    /// - Parameters:
    ///   - observer: The observer corodinate.
    ///   - dateRange: The range of the satellite pass search.
    ///   - coarseInterval: The coarse interval to hunt for a rough window when satellite appearing above horizonal.
    ///   - fineInterval: The fine interval in which the ephemerides and detailed pass info are generated.
    /// - Returns: Information about a list of satellite passes.
    public func findPasses(
        observer: LatLonAlt,
        param: PassFindingParam
    ) -> (passes: [PassInformation], fineSnapshots: Map<Date, SatelliteSnapshot>) {
        let coarseSnapshots: Map<Date, SatelliteSnapshot>
        switch param {
        case let .dateRange(dateRange, coarseInterval, _):
            coarseSnapshots = snapshots(
                observer: observer,
                dateRange: dateRange,
                interval: coarseInterval
            )
        case let .existingSnapshots(snapshots, _):
            coarseSnapshots = snapshots
        }

        guard let firstSnapshot = coarseSnapshots.first?.1 else {
            return ([], Map())
        }

        var snapshotBeforeRising: SatelliteSnapshot?
        var snapshotAfterSetting: SatelliteSnapshot?
        var passInformation = [PassInformation]()
        var resultSnapshots = coarseSnapshots

        func tryGenerateFinePassInfo() {
            guard let fromSnapshot = snapshotBeforeRising, let toSnapshot = snapshotAfterSetting else {
                return
            }

            let fineSnapshots = snapshots(
                observer: observer,
                dateRange: fromSnapshot.date..<toSnapshot.date,
                interval: param.fineInterval
            )

            // Use a cheaper quadratic interpolation to find
            // RST time.
            let elevInterp = quadraticInterpolate(fineSnapshots.map { ($0.0.julianDate, $0.1.position.elev) }, steps: 3000)
            let maxElevPair = elevInterp.max(by: { $0.1 < $1.1 }).map { (Date(julianDate: $0), $1) }!
            let risesAtPair: (Date, Double)? = {
                for index in elevInterp.indices where index < elevInterp.index(before: elevInterp.endIndex) {
                    if elevInterp[index].1 <= 0 && elevInterp[elevInterp.index(after: index)].1 > 0 {
                        let result = elevInterp[elevInterp.index(after: index)]
                        return (
                            Date(julianDate: result.0),
                            result.1
                        )
                    }
                }
                return nil
            }()
            let setsAtPair: (Date, Double)? = {
                for index in elevInterp.indices where index < elevInterp.index(before: elevInterp.endIndex) {
                    if elevInterp[index].1 > 0 && elevInterp[elevInterp.index(after: index)].1 <= 0 {
                        let result = elevInterp[elevInterp.index(after: index)]
                        return (
                            Date(julianDate: result.0),
                            result.1
                        )
                    }
                }
                return nil
            }()

            var illuminationChanges = [PassInformation.Illumination.Change]()

            for index in fineSnapshots.indices where index < fineSnapshots.index(before: fineSnapshots.endIndex) {
                let snapshot1 = fineSnapshots[index].1
                let snapshot2 = fineSnapshots[fineSnapshots.index(after: index)].1

                if snapshot1.isIlluminated && !snapshot2.isIlluminated {
                    illuminationChanges.append(.entersShadow(date: snapshot2.date))
                } else if !snapshot1.isIlluminated && snapshot2.isIlluminated {
                    illuminationChanges.append(.exitsShadow(date: snapshot2.date))
                }
            }

            let sunElev = azel(
                time: maxElevPair.0,
                site: (observer.lat, observer.lon),
                cele: solarGeo(julianDays: maxElevPair.0.julianDate)
            ).alt

            passInformation.append(
                PassInformation(
                    rise: risesAtPair.map { PassInformation.DateElev(date: $0.0, elev: $0.1) },
                    set: setsAtPair.map { PassInformation.DateElev(date: $0.0, elev: $0.1) },
                    transit: PassInformation.DateElev(
                        date: maxElevPair.0, elev: maxElevPair.1
                    ),
                    illumination: PassInformation.Illumination(
                        initiallyIlluminated: fineSnapshots.first!.1.isIlluminated,
                        changes: illuminationChanges
                    ),
                    sunElevationAtTransit: sunElev
                )
            )

            resultSnapshots = resultSnapshots.merging(fineSnapshots)

            snapshotBeforeRising = nil
            snapshotAfterSetting = nil
        }

        if firstSnapshot.position.elev > 0 {
            snapshotBeforeRising = firstSnapshot
        }

        for index in coarseSnapshots.indices where index < coarseSnapshots.index(before: coarseSnapshots.endIndex) {
            let snapshot1 = coarseSnapshots[index].1
            let snapshot2 = coarseSnapshots[coarseSnapshots.index(after: index)].1

            if snapshot1.position.elev <= 0 && snapshot2.position.elev > 0 {
                snapshotBeforeRising = snapshot1
            }

            if snapshot1.position.elev > 0 && snapshot2.position.elev <= 0 {
                snapshotAfterSetting = snapshot2
            }

            tryGenerateFinePassInfo()
        }

        if coarseSnapshots.last!.1.position.elev > 0 {
            snapshotAfterSetting = coarseSnapshots.last!.1
        }

        tryGenerateFinePassInfo()

        return (passInformation, resultSnapshots)
    }
}
