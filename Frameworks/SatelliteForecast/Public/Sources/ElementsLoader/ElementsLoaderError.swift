//
//  ElementsLoaderError.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 7/9/21.
//

import Foundation
@preconcurrency import SatelliteKit

public enum ElementsLoaderError: Error, LocalizedError {
    case elements(SatKitError)
    case unexpectedMimeType(String?)
    case expired(Date, freshDuration: TimeInterval)
    case fileManager(Error)
    case data(Error)
    case other(Error)

    /// Wrap an error with `ElementsLoaderError`. If the error is an `ElementsLoaderError`, return it directly.
    /// - Parameter error: An error to be wrapped.
    /// - Returns: A wrapped error within `ElementsLoaderError`.
    public static func wrapError(_ error: Error) -> ElementsLoaderError {
        if let elementsLoaderError = error as? ElementsLoaderError {
            return elementsLoaderError
        } else if let satKitError = error as? SatKitError {
            return .elements(satKitError)
        } else {
            return .other(error)
        }
    }

    public var errorDescription: String? {
        switch self {
        case let .elements(error):
            return error.localizedDescription
        case .unexpectedMimeType(let mimeType):
            let format = NSLocalizedString(
                "ElementsLoaderError.unexpectedMimeType.description",
                tableName: nil,
                bundle: .main,
                value: "Unexpected mime type %@ found for satellite elements.",
                comment: "Description for ElementsLoaderError.unexpectedMimeType"
            )
            return String(format: format, mimeType ?? "none")
        case .expired(let modifiedDate, freshDuration: let freshDuration):
            let format = NSLocalizedString(
                "ElementsLoaderError.expired.format",
                tableName: nil,
                bundle: .main,
                value: "Ephemerides last modified at %@ has expired. Max duration is %d seconds.",
                comment: "Description for ElementsLoaderError.expired"
            )
            return String(format: format, modifiedDate.formatted(), freshDuration)
        case .fileManager(let error), .data(let error), .other(let error):
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
