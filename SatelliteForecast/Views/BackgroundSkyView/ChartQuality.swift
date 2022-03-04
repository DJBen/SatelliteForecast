//
//  ChartQuality.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/4/22.
//

import Foundation

/// The sky chart quality. Use `full` for full screen display and `preview` for displaying in a list.
enum ChartQuality {
    case full
    case preview
}

extension ChartQuality: Equatable {}
