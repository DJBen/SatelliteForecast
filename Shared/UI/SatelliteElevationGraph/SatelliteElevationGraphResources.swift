//
//  SatelliteElevationGraphResources.swift
//  SatelliteForcast (iOS)
//
//  Created by Ben Lu on 7/4/21.
//

import Foundation
import UIKit

struct SatelliteElevationGraphResources: Equatable {
    struct RangeImage: Equatable {
        let julianDateRange: Range<Double>
        let image: UIImage
    }
    var rasterizedElevationGraphs: [Int: RangeImage] = [:]

    static var empty: SatelliteElevationGraphResources {
        SatelliteElevationGraphResources()
    }
}
