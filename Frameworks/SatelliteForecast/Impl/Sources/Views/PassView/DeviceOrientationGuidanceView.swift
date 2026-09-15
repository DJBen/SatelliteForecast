import SwiftUI
import CoreMotion
import SatelliteForecast

/// A short, dismissible demonstration that stays with the chart it controls.
struct DeviceOrientationGuidanceView: View {
    let deviceMotionResult: Loadable<CMDeviceMotion, Error>
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
            if !dismissed && !hasAligned && !isAligned {
                HStack(spacing: 16) {
                    phoneDemonstration
                        .frame(width: 64, height: 100)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Lift your iPhone")
                            .font(.headline)
                        Text("Camera up. Screen down.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.trailing, 8)
                }
                .padding(20)
                .padding(.trailing, 8)
                .frame(maxWidth: 310)
                .glassEffect(.regular, in: .rect(cornerRadius: 26))
                .overlay(alignment: .topTrailing) {
                    Button {
                        dismissed = true
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dismiss orientation guidance")
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: dismissed)
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
