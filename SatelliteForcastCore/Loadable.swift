//
//  Loadable.swift
//  SatelliteForcastCore
//
//  Created by Ben Lu on 6/4/21.
//

import Foundation

public enum Loadable<T> {
    case neverLoaded

    /// This case is used to mark an object as "will load" so that it will be
    /// picked up by the middleware to trigger loading.
    case loading
    case loaded(T)

    public var value: T? {
        switch self {
        case let .loaded(value):
            return value
        case .neverLoaded, .loading:
            return nil
        }
    }
}
extension Loadable: Equatable where T: Equatable {}
