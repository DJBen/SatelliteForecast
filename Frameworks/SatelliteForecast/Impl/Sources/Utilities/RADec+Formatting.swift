//
//  RADec+Formatting.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 11/22/22.
//

import SatelliteKit

extension RADec {
    public var formattedRA: String {
        let (hours, minutes, seconds) = ra.hms
        return String(format: "%dh %dm %ds", hours, minutes, seconds)
    }

    public var formattedDec: String {
        let (hours, minutes, seconds) = dec.dms
        return String(format: "%d°%d'%d\"", hours, minutes, seconds)
    }
}

