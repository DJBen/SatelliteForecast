//
//  CoreGraphics+Utils.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 11/22/22.
//

import CoreGraphics

extension CGPoint {
    func distance(from point: CGPoint) -> CGFloat {
        return sqrt((x - point.x) * (x - point.x) + (y - point.y) * (y - point.y))
    }
}
