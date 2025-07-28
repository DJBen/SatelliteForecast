//
//  DebugMenuConfig.swift
//  SatelliteForecastPackage
//
//  Created by Sihao Lu on 7/27/25.
//

public struct DebugMenuConfig: Equatable {
    public var isDebugMenuVisible: Bool = false
    public var frozenAt: Double?
    public var mockedOffsetOn: Bool = false
    public var rapidNotificationDelivery: Bool = false

    /// Offset in days between the real julian date and the mocked julian date. Positive value means mocked date is in the future,
    /// while negative value means mocked date is in the past.
    public var mockedOffset: Double = 0

    /// The julian date offset in effect.
    public var effectiveOffset: Double {
        mockedOffsetOn ? mockedOffset : 0
    }

    public init() {}
}
