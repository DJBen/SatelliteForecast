//
//  SatelliteForecastApp.swift
//  Shared
//
//  Created by Ben Lu on 5/28/21.
//

import SwiftUI
@preconcurrency import SatelliteKit
import CoreMotion
import SatelliteForecast
import SatelliteForecastImpl
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
                        Label(AppLocalization.text("Unable to load the sky catalog"), systemImage: "star.slash")
                    } description: {
                        Text(loadError)
                    } actions: {
                        Button(AppLocalization.text("Try again")) { loadAttempt += 1 }
                    }
                } else {
                    ProgressView(AppLocalization.text("Loading the sky…"))
                }
            }
            .onOpenURL { appDelegate.open($0) }
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
    @State private var session: AppSession
    @Environment(\.scenePhase) private var scenePhase
    private let motionManager = CMMotionManager()
    init(starManager: AppStarCatalog, appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        _session = State(initialValue: AppSession(catalog: starManager))
    }
    var body: some View {
        Group {
            if session.hasCompletedOnboarding { NativeRootView(session: session) }
            else { OnboardingView(session: session) { session.completeOnboarding() } }
        }
        .sheet(isPresented: Binding(get: { session.debug.config.isDebugMenuVisible }, set: { session.debug.config.isDebugMenuVisible = $0 })) { DebugMenu(viewModel: session.debug) }
        .onAppear {
            appDelegate.onLifecycle = { session.handle($0) }
            appDelegate.onDeepLink = { session.open($0, id: $1, observer: $2, passTime: $3) }
            appDelegate.onURL = { link in
                session.open(link.category, id: link.noradIndex, observer: link.observer,
                    passTime: link.passTime, fromNotification: false)
            }
            session.location.start()
        }
        .onChange(of: scenePhase) { old, new in session.handle(.scenePhaseDidChange(old, new)) }
        .onReceive(NotificationCenter.default.publisher(for: .deviceDidShakeNotification)) { _ in
            #if DEBUG
            session.debug.config.isDebugMenuVisible = true
            #endif
        }
        .environment(\.motionManagerKey, motionManager)
        .overlay {
            if session.settings.isNightModeOn { Color(uiColor: .red).blendMode(.plusDarker).allowsHitTesting(false) }
        }
    }
}
