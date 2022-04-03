//
//  EnvironmentKeys.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/16/22.
//

import SwiftUI

struct BackgroundSkyJulianDateKeyEnvironmentKey: EnvironmentKey {
    static let defaultValue: Double? = nil
}

extension EnvironmentValues {
    var backgroundSkyJulianDateKey: Double? {
        get { self[BackgroundSkyJulianDateKeyEnvironmentKey.self] }
        set { self[BackgroundSkyJulianDateKeyEnvironmentKey.self] = newValue }
    }
}

struct JulianDateRangeKey: EnvironmentKey {
    static let defaultValue: ClosedRange<Double>? = nil
}

extension EnvironmentValues {
    var julianDateRangeKey: ClosedRange<Double>? {
        get { self[JulianDateRangeKey.self] }
        set { self[JulianDateRangeKey.self] = newValue }
    }
}
