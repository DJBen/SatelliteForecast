//
//  SatelliteForecastWidgetBundle.swift
//  SatelliteForecastWidget
//
//  Created by Sihao Lu on 7/26/25.
//

import WidgetKit
import SwiftUI

@main
struct SatelliteForecastWidgetBundle: WidgetBundle {
    var body: some Widget {
        SatelliteForecastWidget()
        SatelliteForecastWidgetControl()
        SatelliteForecastWidgetLiveActivity()
    }
}
