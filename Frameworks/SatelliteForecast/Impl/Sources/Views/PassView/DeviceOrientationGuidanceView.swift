import SwiftUI
import CoreMotion
import SatelliteForecast

/// A short, dismissible demonstration that stays with the chart it controls.
struct DeviceOrientationGuidanceView: View {
    let deviceMotionResult: Loadable<CMDeviceMotion, Error>
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("hasDismissedOrientationGuidance") private var hasDismissedGuidance = false
    @AppStorage("orientationGuidanceDismissalCount") private var dismissalCount = 0
    @AppStorage("orientationGuidanceSuppressed") private var suppressed = false
    @State private var expanded = false
    @State private var dismissed = false
    @State private var hasAligned = false

    // Positive device Z gravity means the screen faces down and the back faces up.
    static func isAligned(gravityZ: Double) -> Bool {
        gravityZ.isFinite && gravityZ >= cos(.pi / 6)
    }

    private var isAligned: Bool {
        deviceMotionResult.content.map { Self.isAligned(gravityZ: $0.gravity.z) } ?? false
    }

    var body: some View {
        Group {
            if !suppressed && !dismissed && !hasAligned && !isAligned {
                if hasDismissedGuidance && !expanded {
                    Button {
                        expanded = true
                    } label: {
                        phoneDemonstration
                            .frame(width: 64, height: 100)
                            .scaleEffect(0.65)
                            .frame(width: 56, height: 88)
                            .contentShape(RoundedRectangle(cornerRadius: 16))
                            .accessibilityHidden(true)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
                    .accessibilityLabel(AppLocalization.text("Lift your iPhone"))
                    .accessibilityHint(AppLocalization.text("Show orientation guidance"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .transition(.opacity)
                } else {
                    VStack(spacing: 16) {
                        HStack(spacing: 16) {
                            phoneDemonstration
                                .frame(width: 64, height: 100)
                                .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Lift your iPhone", bundle: .module)
                                    .font(.headline)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text("Camera up. Screen down.", bundle: .module)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.trailing, 8)
                        }
                        if dismissalCount >= 2 {
                            Button {
                                suppressed = true
                            } label: {
                                Text("Don't show again", bundle: .module)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.glass)
                        }
                    }
                    .padding(20)
                    .padding(.trailing, 8)
                    .frame(maxWidth: 310)
                    .glassEffect(.regular, in: .rect(cornerRadius: 26))
                    .overlay(alignment: .topTrailing) {
                        Button {
                            dismissalCount = min(dismissalCount + 1, 2)
                            hasDismissedGuidance = true
                            expanded = false
                            dismissed = true
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(AppLocalization.text("Dismiss orientation guidance"))
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: hasDismissedGuidance)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: expanded)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: dismissed)
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
