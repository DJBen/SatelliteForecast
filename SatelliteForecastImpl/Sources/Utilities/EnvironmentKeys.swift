//
//  EnvironmentKeys.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/16/22.
//

import SwiftUI

public struct BackgroundSkyJulianDateKeyEnvironmentKey: EnvironmentKey {
    public static let defaultValue: Double? = nil
}

extension EnvironmentValues {
    public var backgroundSkyJulianDateKey: Double? {
        get { self[BackgroundSkyJulianDateKeyEnvironmentKey.self] }
        set { self[BackgroundSkyJulianDateKeyEnvironmentKey.self] = newValue }
    }
}

public struct JulianDateRangeKey: EnvironmentKey {
    public static let defaultValue: ClosedRange<Double>? = nil
}

extension EnvironmentValues {
    public var julianDateRangeKey: ClosedRange<Double>? {
        get { self[JulianDateRangeKey.self] }
        set { self[JulianDateRangeKey.self] = newValue }
    }
}
