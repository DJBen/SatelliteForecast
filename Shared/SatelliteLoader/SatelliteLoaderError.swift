//
//  SatelliteLoaderError.swift
//  SatelliteForcast
//
//  Created by Ben Lu on 7/9/21.
//

import Foundation
import SatelliteKit

enum SatelliteLoaderError: Error, LocalizedError {
    case tle(SatKitError)
    case other(Error)

    var errorDescription: String? {
        switch self {
        case let .tle(error):
            return error.localizedDescription
        case let .other(error):
            let nsError = error as NSError
            return nsError.localizedDescription
        }
    }
}

extension SatelliteLoaderError: Equatable {
    static func == (lhs: SatelliteLoaderError, rhs: SatelliteLoaderError) -> Bool {
        switch (lhs, rhs) {
        case let (.tle(e1), .tle(e2)):
            return e1 == e2
        case let (.other(e1), .other(e2)):
            return String(describing: e1) == String(describing: e2)
        default:
            return false
        }
    }
}
