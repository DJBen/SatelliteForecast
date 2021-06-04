//
//  Loadable.swift
//  SatelliteForcastCore
//
//  Created by Ben Lu on 6/4/21.
//

import Foundation

public enum Loadable<T> {
    case neverLoaded
    case loading
    case loaded(T)
}
extension Loadable: Equatable where T: Equatable {}
