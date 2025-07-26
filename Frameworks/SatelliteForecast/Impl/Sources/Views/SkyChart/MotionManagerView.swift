//
//  MotionManagerView.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 4/9/22.
//

import CoreMotion
import SatelliteForecast
import SwiftUI

/// A view managing motion manager updates and injecting device motion data into the environment
public struct MotionManagerView<Content: View>: View {
    @Environment(\.motionManagerKey) var motionManager

    @Binding var isActive: Bool
    var content: (Loadable<CMDeviceMotion, Error>) -> Content

    @State var refreshTimer = Timer.publish(
        every: 0.05,
        on: .main,
        in: .common
    )
    .autoconnect()
    .map(\.julianDate)

    @State var julianDate: Double?

    init(
        isActive: Binding<Bool> = .constant(true),
        @ViewBuilder content: @escaping (Loadable<CMDeviceMotion, Error>) -> Content
    ) {
        self._isActive = isActive
        self.content = content
    }

    @State private var deviceMotionResult: Loadable<CMDeviceMotion, Error> = .notLoaded

    public var body: some View {
        if let motionManager = motionManager {
            content(deviceMotionResult)
            .background(
                Group {
                    if motionManager.isDeviceMotionAvailable {
                        Color.clear.onChange(of: isActive, initial: true) { _, isActive in
                            if isActive {
                                print("Motion manager: startDeviceMotionUpdates")
                                motionManager.deviceMotionUpdateInterval = 0.05
                                motionManager.startDeviceMotionUpdates(using: .xTrueNorthZVertical)
                            } else {
                                print("Motion manager: stopDeviceMotionUpdates")
                                motionManager.stopDeviceMotionUpdates()
                            }
                        }
                    } else {
                        Color.clear
                    }
                }
            )
            .onReceive(refreshTimer) { _ in
                guard isActive else {
                    return
                }
                if let deviceMotion = motionManager.deviceMotion {
                    deviceMotionResult = .loaded(deviceMotion)
                }
            }
        } else {
            // Motion manager not injected in environment
            Text(verbatim: "Motion manager not injected in environment")
        }
    }
}
