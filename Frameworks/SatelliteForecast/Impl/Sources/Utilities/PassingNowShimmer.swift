import SatelliteWidgetSupport
import SwiftUI

/// Shared live-pass emphasis. Only this text overlay ticks; the surrounding sky stays independent.
struct PassingNowShimmer: ViewModifier {
    static let coral = MoonstonePalette.passing
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .foregroundStyle(Self.coral)
            .overlay {
                if !reduceMotion && scenePhase == .active {
                    TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
                        let phase = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3) / 3
                        GeometryReader { geometry in
                            LinearGradient(colors: [.clear, .white.opacity(0.9), .clear],
                                startPoint: .leading, endPoint: .trailing)
                                .frame(width: geometry.size.width * 0.6)
                                .offset(x: geometry.size.width * (phase * 2.2 - 0.6))
                        }
                    }
                    .mask(content)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
                }
            }
    }
}
