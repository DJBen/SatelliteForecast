//
//  PassNotification.swift
//  PassNotification
//
//  Created by Ben Lu on 8/18/21.
//

import Foundation
import SatelliteForecast
@preconcurrency import SatelliteKit

public struct ScheduledPassNotification: Sendable {
    public let id: String
    public let notification: PassNotification

    public init(id: String, notification: PassNotification) {
        self.id = id
        self.notification = notification
    }
}

extension ScheduledPassNotification: Identifiable {}
extension ScheduledPassNotification: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
extension ScheduledPassNotification: Equatable {}
extension ScheduledPassNotification: Codable {}

public struct PassNotification: Sendable {
    public let pass: Pass
    public let satelliteName: String
    public let category: SatelliteCategory
    public let observer: LatLonAlt
    public let timing: Timing
    public let timeOffset: TimeInterval

    public enum Timing: Equatable, Codable, CaseIterable, Sendable {
        case rise
        case set
        case transit
        case highestIlluminated
    }

    public init(
        pass: Pass,
        satelliteName: String,
        category: SatelliteCategory,
        observer: LatLonAlt,
        timing: Timing,
        timeOffset: TimeInterval
    ) {
        self.pass = pass
        self.satelliteName = satelliteName
        self.category = category
        self.observer = observer
        self.timing = timing
        self.timeOffset = timeOffset
    }

    public var alertJulianDate: Double {
        let baseJulianDate: Double
        switch timing {
        case .rise:
            baseJulianDate = pass.rise.julianDate
        case .set:
            baseJulianDate = pass.set.julianDate
        case .transit:
            baseJulianDate = pass.transit.julianDate
        case .highestIlluminated:
            baseJulianDate = pass.highestIlluminated?.julianDate ?? 0
        }
        return baseJulianDate + timeOffset * TimeConstants.sec2day
    }
}

extension PassNotification: Equatable {}
extension PassNotification: Codable {}
