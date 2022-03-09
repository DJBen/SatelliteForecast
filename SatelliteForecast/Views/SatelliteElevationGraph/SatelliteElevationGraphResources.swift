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
    var rasterizedElevationGraphs: [UInt: RangeImage] = [:]
}
