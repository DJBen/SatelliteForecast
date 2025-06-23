//
//  CompassAttitudeView.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 4/9/22.
//

import CoreMotion
@preconcurrency import SatelliteKit
import SatelliteForecast
import SwiftUI

public struct CompassAttitudeView: View {
    @Environment(\.motionManagerKey) var motionManager

    var deviceMotion: Loadable<CMDeviceMotion, Error>

    @ViewBuilder private func content(_ motion: CMDeviceMotion) -> some View {
        AuxiliaryCompassView(
            aziEleProvider: AziEle(
                azim: limit360(-(motion.attitude.yaw * rad2deg + 90)),
                elev: motion.attitude.pitch * rad2deg
            )
        )
    }

    @ViewBuilder private func errorContent(_ error: Error) -> some View {
        Text("Errored")
    }

    public var body: some View {
        if let motionManager = motionManager {
            if motionManager.isDeviceMotionAvailable {
                LoadableView(
                    loadableContent: deviceMotion,
                    contentView: { result in
                        content(result)
                    },
                    loadingView: {
                        Color.red
                    },
                    notLoadedView: {
                        Color.clear
                    },
                    failureView: { result in
                        errorContent(result)
                    }
                )
                .id(deviceMotion.content?.attitude)
            } else {
                Color.clear
            }
        } else {
            Text("Motion manager not injected in environment")
        }
    }
}
