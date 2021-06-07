//
//  Satellite+Convenience.swift
//  SatelliteForcastCore
//
//  Created by Ben Lu on 6/4/21.
//

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
    ) -> [SatelliteSnapshot] {
        stride(
            from: dateRange.lowerBound.julianDate,
            to: dateRange.upperBound.julianDate,
            by: interval * TimeConstants.sec2day
        )
        .map { (julianDate) -> SatelliteSnapshot in
            snapshot(julianDate: julianDate, observer: observer)
        }
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
            [SatelliteSnapshot],
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
    ) -> [PassInformation] {
        let coarseSnapshots: [SatelliteSnapshot]
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

        guard let firstSnapshot = coarseSnapshots.first else {
            return []
        }

        var snapshotBeforeRising: SatelliteSnapshot?
        var snapshotAfterSetting: SatelliteSnapshot?
        var passInformation = [PassInformation]()

        func tryGenerateFinePassInfo() {
            guard let fromSnapshot = snapshotBeforeRising, let toSnapshot = snapshotAfterSetting else {
                return
            }

            let fineSnapshots = snapshots(
                observer: observer,
                dateRange: fromSnapshot.date..<toSnapshot.date,
                interval: param.fineInterval
            )

            var illuminationChanges = [PassInformation.IlluminationChange]()
            var risesAt: Date?
            var setsAt: Date?
            for i in 0..<fineSnapshots.count - 1 {
                let snapshot1 = fineSnapshots[i]
                let snapshot2 = fineSnapshots[i + 1]

                if snapshot1.isIlluminated && !snapshot2.isIlluminated {
                    illuminationChanges.append(.entersShadow(date: snapshot2.date))
                } else if !snapshot1.isIlluminated && snapshot2.isIlluminated {
                    illuminationChanges.append(.exitsShadow(date: snapshot2.date))
                }

                if snapshot1.position.elev <= 0 && snapshot2.position.elev > 0 {
                    risesAt = snapshot2.date
                }

                if snapshot1.position.elev > 0 && snapshot2.position.elev <= 0 {
                    setsAt = snapshot2.date
                }
            }
            passInformation.append(
                PassInformation(
                    risesAt: risesAt,
                    setsAt: setsAt,
                    illuminationChanges: illuminationChanges,
                    snapshots: fineSnapshots
                )
            )

            snapshotBeforeRising = nil
            snapshotAfterSetting = nil
        }

        if firstSnapshot.position.elev > 0 {
            snapshotBeforeRising = firstSnapshot
        }

        for i in 0..<coarseSnapshots.count - 1 {
            let snapshot1 = coarseSnapshots[i]
            let snapshot2 = coarseSnapshots[i + 1]

            if snapshot1.position.elev <= 0 && snapshot2.position.elev > 0 {
                snapshotBeforeRising = snapshot1
            }

            if snapshot1.position.elev > 0 && snapshot2.position.elev <= 0 {
                snapshotAfterSetting = snapshot2
            }

            tryGenerateFinePassInfo()
        }

        if coarseSnapshots.last!.position.elev > 0 {
            snapshotAfterSetting = coarseSnapshots.last!
        }

        tryGenerateFinePassInfo()

        return passInformation
    }
}
