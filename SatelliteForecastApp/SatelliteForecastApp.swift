//
//  SatelliteForecastApp.swift
//  Shared
//
//  Created by Ben Lu on 5/28/21.
//

import SwiftUI
@preconcurrency import SatelliteKit
import SatelliteForecast
@preconcurrency import SwiftRex
@preconcurrency import CombineRex
@preconcurrency import CombineRextensions
import CoreMotion
import SatelliteForecastImplWiring

@main
struct SatelliteForecastApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @StateObject var store = Store.shared.asObservableViewModel(
        initialState: .init(),
        emitsValue: .whenDifferent
    )
    @Environment(\.scenePhase) private var scenePhase
    let motionManager = CMMotionManager()

    var body: some Scene {
        WindowGroup {
            ViewProducer.root(
                viewModel: store
            )
            .view(
                RootViewContext(
                    julianDateProvider: { Date().julianDate }
                )
            )
            .sheet(
                isPresented: Binding<Bool>(
                    get: {
                        store.state.debugMenu.isDebugMenuVisible
                    },
                    set: { newValue in
                        store.dispatch(
                            .debugMenu(.toggleDebugMenu(newValue))
                        )
                    }
                ),
                onDismiss: nil,
                content: {
                    ViewProducer<Void, DebugMenu>.debugMenu(
                        viewModel: store
                    )
                    .view()
                }
            )
            .onAppear {
                store.dispatch(.location(.requestAuthorization))
            }
            .onChange(of: scenePhase) { _, phase in
                store.dispatch(.appDelegate(.scenePhaseDidChange(phase)))
            }
            .onReceive(NotificationCenter.default.publisher(for: .deviceDidShakeNotification)) { _ in
                #if DEBUG
                store.dispatch(.debugMenu(.toggleDebugMenu(true)))
                #endif
            }
            .environment(\.motionManagerKey, motionManager)
            .overlay {
                if store.state.isNightModeOn {
                    Color(
                        uiColor: UIColor.red
                    )
                    .blendMode(.plusDarker)
                    .allowsHitTesting(false)
                } else {
                    EmptyView()
                }
            }
        }
    }
}
