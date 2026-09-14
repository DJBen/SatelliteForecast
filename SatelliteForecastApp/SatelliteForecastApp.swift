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
    @State private var catalog: AppStarCatalog?
    @State private var loadError: String?
    @State private var loadAttempt = 0

    var body: some Scene {
        WindowGroup {
            Group {
                if ProcessInfo.processInfo.environment["SATELLITE_SNAPSHOT_TESTS"] == "1" {
                    Color.clear
                } else if let catalog {
                    LoadedSatelliteForecastView(starManager: catalog, appDelegate: appDelegate)
                } else if let loadError {
                    ContentUnavailableView {
                        Label("Unable to load the sky catalog", systemImage: "star.slash")
                    } description: {
                        Text(loadError)
                    } actions: {
                        Button("Try again") { loadAttempt += 1 }
                    }
                } else {
                    ProgressView("Loading the sky…")
                }
            }
            .task(id: loadAttempt) {
                guard catalog == nil, ProcessInfo.processInfo.environment["SATELLITE_SNAPSHOT_TESTS"] != "1" else { return }
                loadError = nil
                do {
                    let loaded = try await AppStarCatalog.load()
                    try Task.checkCancellation()
                    catalog = loaded
                } catch is CancellationError {
                } catch {
                    loadError = error.localizedDescription
                }
            }
        }
    }
}

private struct LoadedSatelliteForecastView: View {
    let appDelegate: AppDelegate
    @StateObject var store: ObservableViewModel<Store.ActionType, Store.StateType>
    @Environment(\.scenePhase) private var scenePhase
    let motionManager: CMMotionManager
    let starManager: AppStarCatalog
    let julianDateProvider: () -> Double
    
    init(starManager: AppStarCatalog, appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        motionManager = CMMotionManager()
        self.starManager = starManager
        julianDateProvider = { Date().julianDate }
        let store = Store(
            starManager: starManager
        ).asObservableViewModel(
            initialState: .init(),
            emitsValue: .whenDifferent
        )
        _store = StateObject(
            wrappedValue: store
        )
    }

    var body: some View {
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
            .task {
                store.dispatch(.initializeAllConstellations(starManager.allConstellations()))
            }
            .onAppear {
                appDelegate.dispatch = { event in store.dispatch(event) }
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
