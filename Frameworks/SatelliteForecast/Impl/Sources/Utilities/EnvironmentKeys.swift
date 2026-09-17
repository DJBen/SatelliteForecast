//
//  EnvironmentKeys.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 3/16/22.
//

import SwiftUI
import CoreMotion
import SatelliteForecast
import StarryNight

// MARK: - BackgroundSkyJulianDateKeyEnvironmentKey

public struct BackgroundSkyJulianDateKeyEnvironmentKey: EnvironmentKey {
    public static let defaultValue: Double? = nil
}

extension EnvironmentValues {
    public var backgroundSkyJulianDateKey: Double? {
        get { self[BackgroundSkyJulianDateKeyEnvironmentKey.self] }
        set { self[BackgroundSkyJulianDateKeyEnvironmentKey.self] = newValue }
    }
}

// MARK: - JulianDateRangeKey

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

// MARK: - MotionManagerKey

public struct MotionManagerKey: EnvironmentKey {
    public static let defaultValue: CMMotionManager? = nil
}

extension EnvironmentValues {
    public var motionManagerKey: CMMotionManager? {
        get { self[MotionManagerKey.self] }
        set { self[MotionManagerKey.self] = newValue }
    }
}

// MARK: - DeviceMotionKey

public struct DeviceMotionKey: EnvironmentKey {
    public static let defaultValue: Loadable<CMDeviceMotion, Error> = .notLoaded
}

extension EnvironmentValues {
    public var deviceMotionKey: Loadable<CMDeviceMotion, Error> {
        get { self[DeviceMotionKey.self] }
        set { self[DeviceMotionKey.self] = newValue }
    }
}

// MARK: - SelectedBackgroundStarKey

/// This is used to pass the selected star to `BackgroundSkyView` that is embedded inside the `SkyChart`.
public struct SelectedBackgroundStarKey: EnvironmentKey {
    public static let defaultValue: Star? = nil
}

extension EnvironmentValues {
    public var selectedBackgroundStarKey: Star? {
        get { self[SelectedBackgroundStarKey.self] }
        set { self[SelectedBackgroundStarKey.self] = newValue }
    }
}

// Screen-level geometry keeps compact layouts independent of device model.
private struct CompactHeightKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var compactHeightLayout: Bool {
        get { self[CompactHeightKey.self] }
        set { self[CompactHeightKey.self] = newValue }
    }
}

struct CompactHeightLayout: ViewModifier {
    func body(content: Content) -> some View {
        GeometryReader { geometry in
            content.environment(\.compactHeightLayout,
                geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom < 740)
        }
    }
}

/// Lets independent buttons in a List row push values onto the owning stack.
/// Avoids a second, item-driven presentation state for the invisible-pass grid.
private struct PassNavigationPathKey: EnvironmentKey {
    static let defaultValue: Binding<NavigationPath>? = nil
}

extension EnvironmentValues {
    var passNavigationPath: Binding<NavigationPath>? {
        get { self[PassNavigationPathKey.self] }
        set { self[PassNavigationPathKey.self] = newValue }
    }
}
