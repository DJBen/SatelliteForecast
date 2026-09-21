import SwiftUI
import MetalKit
import SatelliteForecast
import SatelliteKit

/// The selected pass and observer are deliberately shared with the 2D chart.
struct PlanetariumView: View {
    let context: PassViewContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var controller = PlanetariumController()
    @AppStorage("planetariumLabels") private var labels = true
    @AppStorage("planetariumLines") private var lines = true
    @AppStorage("planetariumFPS") private var showFPS = false

    init(context: PassViewContext, controller: PlanetariumController? = nil) {
        self.context = context
        self._controller = StateObject(wrappedValue: controller ?? PlanetariumController())
    }

    private var stationName: String {
        switch context.satelliteInfo.noradIndex {
        case SpecialSatellite.iss.rawValue: return AppLocalization.text("Station.iss.short")
        case SpecialSatellite.tianhe.rawValue: return AppLocalization.text("Station.tiangong.short")
        default: return context.satelliteCommonName
        }
    }

    var body: some View {
        ZStack {
            PlanetariumSurface(controller: controller).ignoresSafeArea()
            VStack(spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(stationName)
                            .font(.title2.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    HStack(spacing: 0) {
                        Button {
                            controller.setMotionEnabled(!controller.motionEnabled)
                        } label: {
                            Image(systemName: controller.motionEnabled ? "location.north.line.fill" : "location.north.line")
                                .foregroundStyle(controller.motionEnabled ? Color.cyan : Color.primary)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(AppLocalization.text("Follow Device"))
                        .accessibilityValue(AppLocalization.text(controller.motionEnabled ? "On" : "Off"))
                        .accessibilityHint(AppLocalization.text("Move your device to explore the sky. Drag to turn off."))
                        .accessibilityIdentifier("planetarium.followDevice")
                        Menu {
                            Toggle(AppLocalization.text("Constellation labels"), systemImage: "textformat", isOn: $labels)
                            Toggle(AppLocalization.text("Constellation lines"), systemImage: "star", isOn: $lines)
                            Toggle(AppLocalization.text("Show FPS"), systemImage: "speedometer", isOn: $showFPS)
                                .accessibilityIdentifier("planetarium.showFPS")
                        } label: {
                            Image(systemName: "ellipsis")
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .menuActionDismissBehavior(.disabled)
                        .accessibilityLabel(AppLocalization.text("Sky options"))
                        .accessibilityIdentifier("planetarium.options")
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(AppLocalization.text("Close"))
                        .accessibilityIdentifier("planetarium.close")
                    }
                    .padding(.horizontal, 4)
                    .glassEffect(.regular, in: Capsule())
                    .fixedSize()
                }
                if controller.motionEnabled && !controller.motionAvailable {
                    Text("Motion unavailable · Drag to explore the sky", bundle: .module)
                        .font(.caption).padding(10).background(.ultraThinMaterial, in: Capsule())
                }
                PlanetariumStationIndicator(controller: controller, navigation: controller.navigation, stationName: stationName)
                PlanetariumSelectionCard(controller: controller, state: controller.selectionState)
                PlanetariumTimeControls(context: context, controller: controller)
            }
            .padding(20)
            if let error = controller.errorMessage {
                ContentUnavailableView(AppLocalization.text("Planetarium unavailable"), systemImage: "sparkles", description: Text(error)).allowsHitTesting(false)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if showFPS, let monitor = controller.renderer?.frameRate {
                PlanetariumFPSReadout(monitor: monitor)
            }
        }
        .foregroundStyle(.white).tint(.cyan).preferredColorScheme(.dark)
        .onAppear {
            controller.configure(context: context, julianDate: (context.passSnapshots.pass.rise.julianDate + context.passSnapshots.pass.set.julianDate) / 2)
            controller.setOverlays(labels: labels, lines: lines)
            controller.setActive(true)
            controller.setMotionEnabled(true)
            controller.renderer?.frameRate.setEnabled(showFPS)
        }
        .onDisappear {
            controller.renderer?.frameRate.setEnabled(false)
            controller.stop()
        }
        .onChange(of: labels) { _, _ in controller.setOverlays(labels: labels, lines: lines) }
        .onChange(of: lines) { _, _ in controller.setOverlays(labels: labels, lines: lines) }
        .onChange(of: showFPS) { _, value in
            controller.renderer?.frameRate.setEnabled(value)
        }
        .onChange(of: scenePhase) { _, phase in
            controller.setActive(phase == .active)
            controller.renderer?.frameRate.setEnabled(showFPS && phase == .active)
        }

    }


}

private struct PlanetariumFPSReadout: View {
    @ObservedObject var monitor: PlanetariumFrameRate

    var body: some View {
        HStack(spacing: 6) {
            Text("FPS")
                .foregroundStyle(.secondary)
            Text(monitor.framesPerSecond.map { String(format: "%.0f", $0) } ?? "—")
                .monospacedDigit()
        }
        .font(.caption2.weight(.medium))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("planetarium.fps")
        .allowsHitTesting(false)
    }
}

private struct PlanetariumSurface: UIViewRepresentable {
    let controller: PlanetariumController
    func makeUIView(context: Context) -> MTKView { controller.view }
    func updateUIView(_ uiView: MTKView, context: Context) {}
}

/// A directional pointer with an inset tail, leaving the sky visible behind it.
private struct StationDirectionArrow: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - rect.height * 0.27))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}


private struct PlanetariumStationIndicator: View {
    let controller: PlanetariumController
    @ObservedObject var navigation: PlanetariumNavigationState
    let stationName: String
    var body: some View {
                Color.clear
                    .overlay {
                        GeometryReader { geometry in
                            if let bearing = navigation.bearing {
                                let dx = sin(bearing), dy = -cos(bearing)
                                let halfWidth = max(0, geometry.size.width / 2 - 24)
                                let halfHeight = max(0, geometry.size.height / 2 - 24)
                                let distance = min(halfWidth / max(0.0001, abs(dx)), halfHeight / max(0.0001, abs(dy)))
                                Button {
                                    controller.animateToSatellite()
                                } label: {
                                    StationDirectionArrow()
                                        .fill(.white.opacity(0.62))
                                        .frame(width: 26, height: 32)
                                        .rotationEffect(.radians(bearing))
                                        .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
                                        .frame(width: 48, height: 48)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(AppLocalization.text("Find satellite"))
                                .accessibilityValue(stationName)
                                .accessibilityIdentifier("planetarium.offscreenStation")
                                .position(x: geometry.size.width / 2 + dx * distance,
                                          y: geometry.size.height / 2 + dy * distance)
                            }
                        }
                    }
    }
}

private struct PlanetariumTimeControls: View {
    let context: PassViewContext
    let controller: PlanetariumController
    @Environment(\.scenePhase) private var scenePhase
    @State private var progress = 0.5
    @State private var playing = false
    @State private var live = false
    @State private var now = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let timer = Timer.publish(every: 1 / 30, on: .main, in: .common).autoconnect()
    private var julianDate: Double {
        let pass = context.passSnapshots.pass
        return live ? now.julianDate : pass.rise.julianDate + progress * (pass.set.julianDate - pass.rise.julianDate)
    }

    var body: some View {
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(Date(julianDate: julianDate), format: .dateTime.year(.twoDigits).month(.twoDigits).day(.twoDigits))
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                            Text(Date(julianDate: julianDate), format: .dateTime.hour().minute().second())
                                .font(.system(size: 22, weight: .medium, design: .rounded))
                        }
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(reduceMotion || !live ? nil : .default, value: now)
                        .minimumScaleFactor(0.75)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("planetarium.nowClock")
                        Picker(AppLocalization.text("Time mode"), selection: $live) {
                            Text(AppLocalization.text("Now")).tag(true)
                            Text(AppLocalization.text("Preview")).tag(false)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 176)
                        .accessibilityIdentifier("planetarium.timeMode")
                    }
                    if !live {
                        HStack(spacing: 6) {
                            Button(AppLocalization.text(playing ? "Pause preview" : "Play preview"), systemImage: playing ? "pause.fill" : "play.fill") {
                                if progress >= 1 { progress = 0 }
                                playing.toggle()
                            }
                            .labelStyle(.iconOnly)
                            .frame(width: 36, height: 44)
                            Slider(value: $progress, in: 0...1) { editing in
                                if editing { playing = false }
                            }
                            .accessibilityLabel(AppLocalization.text("Pass preview time"))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .onChange(of: live) { _, value in
            playing = false
            if value { now = Date(julianDate: context.julianDateProvider()) }
            controller.setPreviewPlayback(playing: false, date: julianDate, end: context.passSnapshots.pass.set.julianDate, trackingSelection: !value)
        }
        .onChange(of: playing) { _, value in
            controller.setPreviewPlayback(playing: value, date: julianDate, end: context.passSnapshots.pass.set.julianDate, trackingSelection: !live)
        }
        .onChange(of: scenePhase) { _, value in
            if value != .active { playing = false }
        }
        .onChange(of: progress) { _, _ in
            if !playing && !live { controller.updateTime(julianDate, trackingSelection: true) }
        }
        .onReceive(timer) { _ in
            guard scenePhase == .active else { return }
            if live {
                let next = Date(julianDate: context.julianDateProvider())
                if floor(next.timeIntervalSince1970) != floor(now.timeIntervalSince1970) { now = next }
                // Keep the label at 1 Hz, but interpolate the orbit at every tick.
                controller.updateTime(next.julianDate)
                return
            }
            if playing {
                let pass = context.passSnapshots.pass
                let date = controller.previewDate ?? julianDate
                progress = max(0, min(1, (date - pass.rise.julianDate) / max(1 / 86400, pass.set.julianDate - pass.rise.julianDate)))
                if progress >= 1 { playing = false }
            }
        }
    }
}


private struct PlanetariumSelectionCard: View {
    let controller: PlanetariumController
    @ObservedObject var state: PlanetariumSelectionState
    var body: some View {
                if let selection = state.value {
                    HStack(spacing: 12) {
                        if let moonID = selection.moonID, let moon = PlanetariumMoon.all.first(where: { $0.id == moonID }) {
                            Image(uiImage: MoonSurface.image(for: moon)).resizable().scaledToFit()
                                .frame(width: 48, height: 48).accessibilityHidden(true)
                        } else if let planet = selection.planet, PlanetariumGlobeStyle(body: planet) != nil {
                            PlanetariumGlobe(body: planet, appearance: { controller.planetAppearance(for: planet) })
                                .frame(width: 48, height: 48)
                                .accessibilityHidden(true)
                        } else {
                            Image(systemName: "sparkle").font(.title2).foregroundStyle(.cyan)
                                .frame(width: 48, height: 48)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(selection.name).font(.system(.headline, design: .serif))
                            Text(selection.detail).font(.caption).foregroundStyle(.secondary)
                            Text(selection.coordinates).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        Button(AppLocalization.text("Dismiss selection"), systemImage: "xmark") { controller.clearSelection() }
                            .labelStyle(.iconOnly)
                    }
                    .padding(16)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22))
                    .accessibilityElement(children: .contain)
                }
    }
}
