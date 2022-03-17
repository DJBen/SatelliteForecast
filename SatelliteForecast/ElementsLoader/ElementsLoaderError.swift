//
//  ElementsLoaderError.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 7/9/21.
//

import Foundation
import SatelliteKit

public enum ElementsLoaderError: Error, LocalizedError {
    case elements(SatKitError)
    case other(Error)

    public var errorDescription: String? {
        switch self {
        case let .elements(error):
            return error.localizedDescription
        case let .other(error):
            let nsError = error as NSError
            return nsError.localizedDescription
        }
    }
}

extension ElementsLoaderError: Equatable {
    public static func == (lhs: ElementsLoaderError, rhs: ElementsLoaderError) -> Bool {
        switch (lhs, rhs) {
        case let (.elements(e1), .elements(e2)):
            return e1 == e2
        case let (.other(e1), .other(e2)):
            return String(describing: e1) == String(describing: e2)
        default:
            return false
        }
    }
}
