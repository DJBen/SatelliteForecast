//
//  EnvironmentKeys.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 3/16/22.
//

import SwiftUI
import CoreMotion
import SatelliteForecast

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

public struct JulianDateProviderKey: EnvironmentKey {
    public static let defaultValue: (() -> Double)? = nil
}

extension EnvironmentValues {
    public var julianDateProviderKey: (() -> Double)? {
        get { self[JulianDateProviderKey.self] }
        set { self[JulianDateProviderKey.self] = newValue }
    }
}

public struct MotionManagerKey: EnvironmentKey {
    public static let defaultValue: CMMotionManager? = nil
}

extension EnvironmentValues {
    public var motionManagerKey: CMMotionManager? {
        get { self[MotionManagerKey.self] }
        set { self[MotionManagerKey.self] = newValue }
    }
}

public struct DeviceMotionKey: EnvironmentKey {
    public static let defaultValue: Loadable<CMDeviceMotion, Error> = .notLoaded
}

extension EnvironmentValues {
    public var deviceMotionKey: Loadable<CMDeviceMotion, Error> {
        get { self[DeviceMotionKey.self] }
        set { self[DeviceMotionKey.self] = newValue }
    }
}
