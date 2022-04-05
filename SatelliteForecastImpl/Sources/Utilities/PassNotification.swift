//
//  PassNotification.swift
//  PassNotification
//
//  Created by Ben Lu on 8/18/21.
//

import Foundation
import SatelliteForecast
import SatelliteKit

public struct ScheduledPassNotification {
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

public struct PassNotification {
    public let pass: Pass
    public let satelliteName: String
    public let category: SatelliteCategory?
    public let observer: LatLonAlt
    public let timeOffset: TimeInterval

    public init(pass: Pass, satelliteName: String, category: SatelliteCategory?, observer: LatLonAlt, timeOffset: TimeInterval) {
        self.pass = pass
        self.satelliteName = satelliteName
        self.category = category
        self.observer = observer
        self.timeOffset = timeOffset
    }

    public var alertJulianDate: Double {
        pass.rise.julianDate + timeOffset * TimeConstants.sec2day
    }
}

extension PassNotification: Equatable {}
extension PassNotification: Codable {}
