import SwiftUI

/// Shared first-use invitation for station cards and visible passes.
struct DiscoveryGlow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion || SnapshotEnvironment.isEnabled {
                border(bright: true)
            } else {
                PhaseAnimator([false, true]) { bright in
                    border(bright: bright)
                } animation: { _ in
                    .easeInOut(duration: 1.6)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func border(bright: Bool) -> some View {
        RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
            .strokeBorder(AppTheme.accent.opacity(bright ? 0.85 : 0.3), lineWidth: 1.5)
            .background {
                RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                    .strokeBorder(AppTheme.accent.opacity(bright ? 0.4 : 0.08), lineWidth: 5)
                    .blur(radius: bright ? 7 : 3)
            }
            .shadow(color: AppTheme.accent.opacity(bright ? 0.25 : 0.05), radius: 9)
    }
}

/// Shared by every pass chart, regardless of the tab or pass visibility.
struct FirstCompassUseTutorial: ViewModifier {
    let isCompassEnabled: Bool
    @AppStorage("hasCompletedAllPassesOnboarding") private var hasSeenTutorial = false
    @State private var showsVideo = false

    func body(content: Content) -> some View {
        content
            .task(id: isCompassEnabled) {
                guard isCompassEnabled, !hasSeenTutorial else { return }
                // Allow navigation or the Compass control transition to finish.
                // Turning Compass off cancels this pending presentation.
                do { try await Task.sleep(for: .milliseconds(450)) } catch { return }
                guard !hasSeenTutorial else { return }
                hasSeenTutorial = true
                showsVideo = true
            }
            .fullScreenCover(isPresented: $showsVideo) {
                PassTutorialVideo { showsVideo = false }
            }
    }
}

struct PassTutorialVideo: View {
    @AppStorage("hasCompletedAllPassesOnboarding") private var hasSeenTutorial = false
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            TutorialVideoView(onDismiss: onDismiss)
                .ignoresSafeArea(.container, edges: .top)
        }
        .preferredColorScheme(.dark)
        .onAppear { hasSeenTutorial = true }
    }
}
