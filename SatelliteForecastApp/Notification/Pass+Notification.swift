//
//  Pass+Notificatino.swift
//  Pass+Notificatino
//
//  Created by Ben Lu on 8/21/21.
//

import Foundation
import SatelliteForecast

extension Pass {
    /// An unique identifier for pass' notification.
    ///
    /// Note that the identifier has a tolerance up to ~60 seconds, so slight deviations of location
    /// won't make the same pass appear like two separate passes.
    var notificationIdentifier: String {
        // About 86.4s
        func roundToThird(_ value: Double) -> Double {
            (value * 1000).rounded() / 1000
        }
        
        return "\(noradIndex)-r@\(roundToThird(rise.julianDate))-t@\(roundToThird(transit.julianDate))-s@\(roundToThird(`set`.julianDate))"
    }
    
    /// The URL for attachment image for the pass' notification.
    /// - Parameter extension: The extension format, e.g. "png".
    /// - Returns: A URL pointing to the attachment image for the pass' notification.
    func attachmentImageURL(extension: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(notificationIdentifier)
            .appendingPathExtension(`extension`)
    }
}
