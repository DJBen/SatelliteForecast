//
//  SatelliteSnapshot.swift
//  SatelliteForcastCore
//
//  Created by Ben Lu on 6/2/21.
//

import Foundation
import SatelliteKit

/// A snapshot of the satellite of a specific date, coordinate, velocity and whether
/// if it is illuminated by sunlight.
public struct SatelliteSnapshot {
    public let date: Date
    public let position: AziEleDst
    public let isIlluminated: Bool

    /// The sun's elevation, ranging from -90 to 90 degrees.
    public let sunElevation: Double

    public init(
        date: Date,
        position: AziEleDst,
        isIlluminated: Bool,
        sunElevation: Double
    ) {
        self.date = date
        self.position = position
        self.isIlluminated = isIlluminated
        self.sunElevation = sunElevation
    }
}

extension SatelliteSnapshot: Equatable {}

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

    public func snapshots(
        observer: LatLonAlt,
        dateRange: Range<Date>,
        interval: TimeInterval
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
        dateRange: Range<Date>,
        coarseInterval: TimeInterval = 30,
        fineInterval: TimeInterval = 3
    ) -> [PassInformation] {
        let coarseSnapshots = snapshots(
            observer: observer,
            dateRange: dateRange,
            interval: coarseInterval
        )

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
                interval: fineInterval
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

extension Array {
    public func split(belongsToSameGroup: (Element, Element) -> Bool) -> [[Element]] {
        guard let firstElement = first else {
            return [[]]
        }
        var results = [[Element]]()
        var segment = [firstElement]
        for i in startIndex..<endIndex - 1 {
            if belongsToSameGroup(self[i], self[i + 1]) {
                segment.append(self[i + 1])
            } else {
                results.append(segment)
                segment = [self[i + 1]]
            }
        }
        results.append(segment)
        return results
    }
}
