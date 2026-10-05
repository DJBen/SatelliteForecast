import SwiftUI
import CoreMotion
import SatelliteForecast

/// Chart-local guidance: a compact glass cue opens into the center of the chart.
struct DeviceOrientationGuidanceView: View {
    let deviceMotionResult: Loadable<CMDeviceMotion, Error>
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var textSize
    @AppStorage("hasDismissedOrientationGuidance") private var hasDismissedGuidance = false
    @AppStorage("orientationGuidanceDismissalCount") private var dismissalCount = 0
    @AppStorage("orientationGuidanceSuppressed") private var suppressed = false
    @State private var expanded: Bool
    @State private var hasAligned = false
    @Namespace private var transition

    init(deviceMotionResult: Loadable<CMDeviceMotion, Error>,
         initiallyExpanded: Bool = false) {
        self.deviceMotionResult = deviceMotionResult
        self._expanded = State(initialValue: initiallyExpanded)
    }

    // Positive device Z gravity means the screen faces down and the back faces up.
    static func isAligned(gravityZ: Double) -> Bool {
        gravityZ.isFinite && gravityZ >= cos(.pi / 6)
    }

    private var isAligned: Bool {
        deviceMotionResult.content.map { Self.isAligned(gravityZ: $0.gravity.z) } ?? false
    }

    private var compactCue: some View {
        Button { expanded = true } label: {
            VStack(spacing: 0) {
                phoneDemonstration
                    .frame(width: 64, height: 100)
                    .scaleEffect(0.6)
                    .frame(width: 56, height: 70)
                Image(systemName: "ellipsis")
                    .font(.caption.weight(.bold))
                    .padding(.bottom, 10)
            }
            .accessibilityHidden(true)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
        .glassEffectID("orientationGuidance", in: transition)
        .glassEffectTransition(reduceMotion ? .identity : .matchedGeometry)
        .accessibilityLabel(Text("Lift your iPhone", bundle: .module))
        .accessibilityHint(Text("Show orientation guidance", bundle: .module))
        .accessibilityIdentifier("pass.orientationGuidance.open")
    }

    private var expandedGuidance: some View {
        VStack(spacing: 16) {
            let layout = textSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 16))
            layout {
                if !textSize.isAccessibilitySize {
                    phoneDemonstration.frame(width: 64, height: 100).accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Lift your iPhone", bundle: .module).font(.headline)
                    Text("Camera up. Screen down.", bundle: .module)
                        .font(.subheadline).foregroundStyle(AppTheme.muted)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.trailing, 8)
            if dismissalCount >= 2 {
                Button { suppressed = true } label: {
                    Text("Don't show again", bundle: .module)
                        .frame(maxWidth: .infinity, minHeight: 28)
                }
                .buttonStyle(.glass)
                .accessibilityIdentifier("pass.orientationGuidance.suppress")
            }
        }
        .padding(20)
        .padding(.trailing, 8)
        .frame(maxWidth: 310)
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
        .glassEffectID("orientationGuidance", in: transition)
        .glassEffectTransition(reduceMotion ? .identity : .matchedGeometry)
        .overlay(alignment: .topTrailing) {
            Button {
                dismissalCount = min(dismissalCount + 1, 2)
                hasDismissedGuidance = true
                expanded = false
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Dismiss orientation guidance", bundle: .module))
            .accessibilityIdentifier("pass.orientationGuidance.close")
        }
    }

    var body: some View {
        Group {
            if !suppressed && !hasAligned && !isAligned {
                // Morph the glass surface without stretching the text or demonstration.
                GlassEffectContainer {
                    ZStack {
                        if expanded {
                            expandedGuidance
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                                .transition(.opacity)
                        } else {
                            compactCue
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                                .transition(.opacity)
                        }
                    }
                }
            }
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: expanded)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: suppressed)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: isAligned)
        .onChange(of: isAligned, initial: true) { _, aligned in
            if aligned { hasAligned = true }
        }
    }

    private struct LiftPose {
        var angle: Double
        var height: CGFloat
        var arrowOpacity: Double
        var saturation: Double

        static let resting = LiftPose(angle: 65, height: 8, arrowOpacity: 0.4, saturation: 0.05)
        static let overhead = LiftPose(angle: -70, height: -12, arrowOpacity: 1, saturation: 1)
    }

    @ViewBuilder private var phoneDemonstration: some View {
        if reduceMotion || SnapshotEnvironment.isEnabled {
            phone(pose: .overhead)
        } else {
            phone(pose: .resting)
                .keyframeAnimator(initialValue: LiftPose.resting) { _, pose in
                    phone(pose: pose)
                } keyframes: { _ in
                    // One uninterrupted lift, then an explicit timed hold.
                    // Separate eased phases stop at upright, and a phase with
                    // identical values can be skipped instead of holding.
                    KeyframeTrack(\.angle) {
                        CubicKeyframe(-70, duration: 1.7)
                        LinearKeyframe(-70, duration: 1.0)
                        MoveKeyframe(65)
                    }
                    KeyframeTrack(\.height) {
                        CubicKeyframe(-12, duration: 1.7)
                        LinearKeyframe(-12, duration: 1.0)
                        MoveKeyframe(8)
                    }
                    KeyframeTrack(\.arrowOpacity) {
                        LinearKeyframe(1, duration: 1.7)
                        LinearKeyframe(1, duration: 1.0)
                        MoveKeyframe(0.4)
                    }
                    KeyframeTrack(\.saturation) {
                        LinearKeyframe(1, duration: 1.7)
                        LinearKeyframe(1, duration: 1.0)
                        MoveKeyframe(0.05)
                    }
                }
        }
    }

    private func phone(pose: LiftPose) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "arrow.up")
                .font(.body.weight(.semibold))
                .foregroundStyle(.tint)
                .opacity(pose.arrowOpacity)
            RoundedRectangle(cornerRadius: 10)
                .fill(.tint.opacity(0.12))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(.tint, lineWidth: 2)
                }
                .overlay(alignment: .top) {
                    Capsule().fill(.tint).frame(width: 15, height: 4).padding(.top, 6)
                }
                .overlay {
                    Image(systemName: "sparkles")
                        .font(.title3).foregroundStyle(.tint)
                }
                .frame(width: 42, height: 72)
                .rotation3DEffect(.degrees(pose.angle), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
                .offset(y: pose.height)
        }
        .saturation(pose.saturation)
    }
}
