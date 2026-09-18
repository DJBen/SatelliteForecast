import FirebaseAnalytics
import FirebaseCore
import Foundation
import SwiftUI

/// Stable, low-cardinality vocabulary. See Documentation/Analytics.md before changing it.
@MainActor
enum AppAnalytics {
    enum Screen: String {
        case onboarding, forecast, categories, satellites, passes, passDetail = "pass_detail"
        case skyDetail = "sky_detail", skyNow = "sky_now", settings, location, alarms
        case alarmSetup = "alarm_setup", ephemerides
    }

    static func event(_ name: String, screen: Screen, parameters: [String: Any] = [:]) {
        // Test hosts and previews must not initialize Firebase or pollute production data.
        guard ProcessInfo.processInfo.environment["SATELLITE_SNAPSHOT_TESTS"] != "1",
              ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil,
              ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1",
              NSClassFromString("XCTestCase") == nil,
              FirebaseApp.app() != nil else { return }
        #if DEBUG
        // Explicit opt-in uses Firebase DebugView; routine simulator work stays quiet.
        guard ProcessInfo.processInfo.arguments.contains("-FIRDebugEnabled") else { return }
        #endif
        var values = parameters
        values["screen"] = screen.rawValue
        Analytics.logEvent(name, parameters: values)
    }

    static func screen(_ screen: Screen) {
        event(AnalyticsEventScreenView, screen: screen, parameters: [
            AnalyticsParameterScreenName: screen.rawValue,
            AnalyticsParameterScreenClass: screen.rawValue
        ])
    }

    /// One terminal outcome per operation, including cancellation. Monotonic wall time.
    final class Operation {
        private let screen: Screen
        private let operation: String
        private let started = ProcessInfo.processInfo.systemUptime
        private var finished = false
        private let emit: (String, Screen, [String: Any]) -> Void
        init(_ operation: String, screen: Screen,
             emit: @escaping (String, Screen, [String: Any]) -> Void = AppAnalytics.event) {
            self.emit = emit
            self.operation = operation
            self.screen = screen
            emit("operation_started", screen, ["operation": operation])
        }
        func finish(_ outcome: String, count: Int? = nil, reason: String? = nil) {
            guard !finished else { return }
            finished = true
            var values: [String: Any] = [
                "operation": operation, "outcome": outcome,
                "duration_ms": max(0, (ProcessInfo.processInfo.systemUptime - started) * 1000)
            ]
            if let count { values["result_count"] = count }
            if let reason { values["reason"] = reason }
            emit("operation_finished", screen, values)
        }
    }
}

private struct AnalyticsScreenModifier: ViewModifier {
    let screen: AppAnalytics.Screen
    @Environment(\.scenePhase) private var scenePhase
    @State private var appeared = false
    @State private var recorded = false

    func body(content: Content) -> some View {
        content
            .onAppear { appeared = true; recordIfActive() }
            .onDisappear { appeared = false; recorded = false }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { recordIfActive() }
                else if phase == .background { recorded = false }
            }
    }
    private func recordIfActive() {
        guard appeared, !recorded, scenePhase == .active else { return }
        recorded = true
        AppAnalytics.screen(screen)
    }
}

extension View {
    /// Apply to the destination content, not a NavigationStack retaining hidden screens.
    func analyticsScreen(_ screen: AppAnalytics.Screen) -> some View {
        modifier(AnalyticsScreenModifier(screen: screen))
    }
}
