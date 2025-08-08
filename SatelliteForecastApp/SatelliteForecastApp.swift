//
//  SatelliteForecastApp.swift
//  Shared
//
//  Created by Ben Lu on 5/28/21.
//

import SwiftUI
@preconcurrency import SatelliteKit
@preconcurrency import SwiftRex
@preconcurrency import CombineRex
@preconcurrency import CombineRextensions
import CoreMotion
import SatelliteForecast
import SatelliteForecastImpl
import SatelliteForecastImplWiring
import StarryNight

@main
struct SatelliteForecastApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @StateObject var store: ObservableViewModel<Store.ActionType, Store.StateType>
    @Environment(\.scenePhase) private var scenePhase
    let motionManager: CMMotionManager
    let starManager: any StarManaging
    let julianDateProvider: () -> Double
    
    init() {
        motionManager = CMMotionManager()
        let starManager = try! StarManager()
        self.starManager = starManager
        julianDateProvider = { Date().julianDate }
        _store = StateObject(
            wrappedValue: Store(
                starManager: starManager
            ).asObservableViewModel(
                initialState: .init(),
                emitsValue: .whenDifferent
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if store.state.onboardingState.hasCompletedOnboarding {
                    ViewProducer.root(
                        viewModel: store
                    )
                    .view(
                        RootViewContext(
                            starManager: starManager,
                            julianDateProvider: julianDateProvider
                        )
                    )
                } else {
                    OnboardingView {
                        store.dispatch(.onboarding(.complete))
                    }
                }
            }
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
            .onChange(of: scenePhase) { oldPhase, newPhase in
                store.dispatch(.appDelegate(.scenePhaseDidChange(oldPhase, newPhase)))
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
