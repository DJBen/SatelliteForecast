import SatelliteForecast
@preconcurrency import SatelliteKit
import SwiftUI

/// A quiet, one-line description of the current subsatellite point.
struct SatelliteLocationLabel: View {
    let julianDateProvider: () -> Double
    let julianDateOffset: Double
    let loadSatellite: @MainActor () async throws -> SatelliteInfo?

    @Environment(\.scenePhase) private var scenePhase
    @State private var summary: GeographicRegionLookup.Summary?

    var body: some View {
        GeographicLocationCaption(summary: summary)
        .task(id: "\(julianDateOffset)-\(scenePhase)") {
            guard scenePhase == .active || SnapshotEnvironment.isEnabled else { return }
            var info: SatelliteInfo?
            var loadedAt: Date?
            repeat {
                // Reuse orbital elements between updates, but renew them hourly.
                if info == nil || Date().timeIntervalSince(loadedAt ?? .distantPast) >= 3600 {
                    do {
                        info = try await loadSatellite()
                        loadedAt = Date()
                    } catch {
                        guard !Task.isCancelled else { return }
                    }
                }
                if let info, let position = try? Satellite(withTLE: info.elements)
                    .geoPosition(julianDays: julianDateProvider() + julianDateOffset) {
                    let next = await GeographicRegionLookup.shared.summary(latitude: position.lat, longitude: position.lon)
                    guard !Task.isCancelled else { return }
                    summary = next
                } else {
                    summary = nil
                }
                if SnapshotEnvironment.isEnabled { return }
                do { try await Task.sleep(for: .seconds(info == nil ? 60 : 10)) } catch { return }
            } while !Task.isCancelled
        }
    }
}

/// Shared visible and VoiceOver copy, rendered separately from orbital work.
struct GeographicLocationCaption: View {
    let summary: GeographicRegionLookup.Summary?
    @Environment(\.locale) private var locale

    var body: some View {
        HStack(spacing: 6) {
            if let flag = summary?.flag {
                Text(flag).accessibilityHidden(true)
            } else {
                Image(systemName: summary?.isWater == true ? "water.waves" : "globe")
                    .foregroundStyle(AppTheme.accent)
                    .accessibilityHidden(true)
            }
            Text(summary?.compactDescription(locale: locale) ?? GeographicLocalization.text("unavailable", locale: locale))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .font(.caption)
        .foregroundStyle(AppTheme.muted)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(summary?.compactDescription(locale: locale) ?? GeographicLocalization.text("unavailable", locale: locale))
    }
}
