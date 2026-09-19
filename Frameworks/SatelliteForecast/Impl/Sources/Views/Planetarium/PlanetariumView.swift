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
    @State private var gyroscope = true
    @State private var progress = 0.5
    @State private var playing = false
    @State private var live = false
    private let timer = Timer.publish(every: 1 / 30, on: .main, in: .common).autoconnect()

    init(context: PassViewContext, controller: PlanetariumController? = nil) {
        self.context = context
        self._controller = StateObject(wrappedValue: controller ?? PlanetariumController())
    }

    private var julianDate: Double {
        let pass = context.passSnapshots.pass
        return live ? context.julianDateProvider() : pass.rise.julianDate + progress * (pass.set.julianDate - pass.rise.julianDate)
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
                        Text(Date(julianDate: julianDate), format: .dateTime.month().day().hour().minute().second())
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 0) {
                        Button {
                            gyroscope = false
                            controller.animateToSatellite()
                        } label: {
                            Image(systemName: "scope")
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(AppLocalization.text("Find satellite"))
                        .accessibilityIdentifier("planetarium.findSatellite")
                        Menu {
                            Toggle(AppLocalization.text("Constellation labels"), systemImage: "textformat", isOn: $labels)
                            Toggle(AppLocalization.text("Constellation lines"), systemImage: "star", isOn: $lines)
                            Toggle(AppLocalization.text("Gyroscope"), systemImage: "gyroscope", isOn: $gyroscope)
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
                if gyroscope && !controller.motionAvailable {
                    Text("Motion unavailable · Drag to explore the sky", bundle: .module)
                        .font(.caption).padding(10).background(.ultraThinMaterial, in: Capsule())
                }
                Color.clear
                    .overlay {
                        GeometryReader { geometry in
                            if let bearing = controller.stationBearing {
                                let dx = sin(bearing), dy = -cos(bearing)
                                let halfWidth = max(0, geometry.size.width / 2 - 24)
                                let halfHeight = max(0, geometry.size.height / 2 - 24)
                                let distance = min(halfWidth / max(0.0001, abs(dx)), halfHeight / max(0.0001, abs(dy)))
                                Button {
                                    gyroscope = false
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
                if let selection = controller.selection {
                    HStack(spacing: 12) {
                        if let planet = selection.planet, PlanetariumGlobeStyle(body: planet) != nil {
                            PlanetariumGlobe(body: planet)
                                .frame(width: 48, height: 48)
                                .accessibilityHidden(true)
                        } else {
                            Image(systemName: "sparkle").font(.title2).foregroundStyle(.cyan)
                                .frame(width: 48, height: 48)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(selection.name).font(.headline)
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
                VStack(spacing: 12) {
                    HStack {
                        Button(AppLocalization.text(playing ? "Pause preview" : "Play preview"), systemImage: playing ? "pause.fill" : "play.fill") {
                            live = false
                            if progress >= 1 { progress = 0 }
                            playing.toggle()
                        }.labelStyle(.iconOnly).frame(width: 32)
                        Slider(value: $progress, in: 0...1) { editing in
                            if editing { live = false; playing = false }
                        }.accessibilityLabel(AppLocalization.text("Pass preview time"))
                        Button(AppLocalization.text("Live")) { live = true; playing = false }
                            .tint(live ? .cyan : .white)
                    }

                }
                .padding(16).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
            }
            .padding(20)
            if let error = controller.errorMessage {
                ContentUnavailableView(AppLocalization.text("Planetarium unavailable"), systemImage: "sparkles", description: Text(error)).allowsHitTesting(false)
            }
        }
        .foregroundStyle(.white).tint(.cyan).preferredColorScheme(.dark)
        .onAppear {
            controller.configure(context: context, julianDate: julianDate)
            controller.setOverlays(labels: labels, lines: lines)
            controller.setMotionEnabled(gyroscope)
        }
        .onDisappear { controller.stop() }
        .onChange(of: labels) { _, _ in controller.setOverlays(labels: labels, lines: lines) }
        .onChange(of: lines) { _, _ in controller.setOverlays(labels: labels, lines: lines) }
        .onChange(of: gyroscope) { _, value in controller.setMotionEnabled(value) }
        .onChange(of: scenePhase) { _, phase in
            controller.setActive(phase == .active, gyroscope: gyroscope)
        }
        .onReceive(timer) { _ in
            guard scenePhase == .active else { return }
            if playing {
                let seconds = (context.passSnapshots.pass.set.julianDate - context.passSnapshots.pass.rise.julianDate) * 86400
                progress = min(1, progress + 10 / (30 * max(1, seconds)))
                if progress >= 1 { playing = false }
            }
            controller.updateTime(julianDate)
        }
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
