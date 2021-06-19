//
//  CoreGraphics+Hashable.swift
//  SatelliteForcastCore
//
//  Created by Ben Lu on 6/19/21.
//

import CoreGraphics

extension CGSize: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(width)
        hasher.combine(height)
    }
}

