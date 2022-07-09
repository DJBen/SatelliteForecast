//
//  SatelliteElevationGraphResources.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 7/4/21.
//

import Foundation
import UIKit

public struct SatelliteElevationGraphResources: Equatable {
    public struct RangeImage: Equatable {
        public let julianDateRange: ClosedRange<Double>
        public let image: UIImage

        public init(julianDateRange: ClosedRange<Double>, image: UIImage) {
            self.julianDateRange = julianDateRange
            self.image = image
        }
    }
    
    public var rasterizedElevationGraphs: [UInt: [RangeImage]] = [:]

    public init(rasterizedElevationGraphs: [UInt : [SatelliteElevationGraphResources.RangeImage]] = [:]) {
        self.rasterizedElevationGraphs = rasterizedElevationGraphs
    }
    
    public func rasterizedElevationGraph(
        noradIndex: UInt,
        size: CGSize,
        julianDateRange: ClosedRange<Double>,
        tolerance: Double = 1e-8
    ) -> RangeImage? {
        rasterizedElevationGraphs[noradIndex]?.first {
            $0.image.size.height == size.height
            && $0.julianDateRange.roughlyEqualTo(
                julianDateRange,
                tolerance: tolerance
            )
        }
    }
}
