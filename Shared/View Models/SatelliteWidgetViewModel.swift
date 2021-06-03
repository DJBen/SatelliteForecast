//
//  SatelliteWidgetViewModel.swift
//  SatelliteForcast
//
//  Created by Ben Lu on 5/29/21.
//

import Foundation
import SatelliteKit

struct DateHorizontalCoordinate {
    let date: Date
    let horizontalCoordinate: AziEleDst
    let isIlluminated: Bool
}

struct SatelliteWidgetViewModel {
    let satelliteName: String
    let sortedDateHorizontalCoordinates: [DateHorizontalCoordinate]
}
