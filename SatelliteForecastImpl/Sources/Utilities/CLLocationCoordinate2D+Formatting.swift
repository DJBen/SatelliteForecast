//
//  CLLocationCoordinate2D+Formatting.swift
//  CLLocationCoordinate2D+Formatting
//
//  Created by Ben Lu on 8/7/21.
//

import CoreLocation

extension BinaryFloatingPoint {
    fileprivate var dms: (degrees: Int, minutes: Int, seconds: Int) {
        var seconds = Int(self * 3600)
        let degrees = seconds / 3600
        seconds = abs(seconds % 3600)
        return (degrees, seconds / 60, seconds % 60)
    }
}

extension CLLocationCoordinate2D {
    public var formattedString: String {
        var latitudeString: String {
            let (degrees, minutes, seconds) = latitude.dms
            return String(format: "%d°%d'%d\"%@", abs(degrees), minutes, seconds, degrees >= 0 ? "N" : "S")
        }
        var longitudeString: String {
            let (degrees, minutes, seconds) = longitude.dms
            return String(format: "%d°%d'%d\"%@", abs(degrees), minutes, seconds, degrees >= 0 ? "E" : "W")
        }

        return String(
            format: "%@, %@",
            latitudeString,
            longitudeString
        )
    }
}
