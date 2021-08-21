//
//  PassNotification.swift
//  PassNotification
//
//  Created by Ben Lu on 8/18/21.
//

import Foundation
import SatelliteForecastCore
import SatelliteKit

struct ScheduledPassNotification {
    let id: String
    let notification: PassNotification
}

extension ScheduledPassNotification: Identifiable {}
extension ScheduledPassNotification: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
extension ScheduledPassNotification: Equatable {}
extension ScheduledPassNotification: Codable {}

struct PassNotification {
    let pass: Pass
    let satelliteName: String
    let observer: LatLonAlt
    let timeOffset: TimeInterval
    
    var alertJulianDate: Double {
        pass.rise.julianDate + timeOffset * TimeConstants.sec2day
    }
}

extension PassNotification: Equatable {}
extension PassNotification: Codable {}
