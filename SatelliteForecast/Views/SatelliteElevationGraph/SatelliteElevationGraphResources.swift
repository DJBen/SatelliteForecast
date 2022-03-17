//
//  SatelliteElevationGraphResources.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 7/4/21.
//

import Foundation
import UIKit

struct SatelliteElevationGraphResources: Equatable {
    struct RangeImage: Equatable {
        let julianDateRange: ClosedRange<Double>
        let image: UIImage
    }
    var rasterizedElevationGraphs: [UInt: [RangeImage]] = [:]

    func rasterizedElevationGraph(
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
