import SwiftUI

public struct StationPassActivityView: View {
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var typeSize
    public let pass: StationPassActivity
    public let state: StationPassActivity.ContentState
    public var stale: Bool
    public var previewDate: Date?
    public init(pass: StationPassActivity, state: StationPassActivity.ContentState, stale: Bool = false, previewDate: Date? = nil) {
        self.pass = pass; self.state = state; self.stale = stale; self.previewDate = previewDate
    }
    private func text(_ key: String) -> String { WidgetStrings.text(key, locale: locale) }
    private var spaciousText: Bool { typeSize > .large }
    private var statusKey: String? {
        if stale { return "live.openUpdate" }
        if state.phase == .shadow { return "live.inShadow" }
        if state.phase == .ended { return "live.finished" }
        return nil
    }
    private var label: String {
        if stale { return text("live.set") }
        switch state.phase {
        case .ended: return text("live.complete")
        case .upcoming: return text("live.untilVisible")
        case .shadow: return text(state.target < pass.set ? "live.untilVisible" : "live.untilSet")
        case .visible: return text(state.targetsShadow ? "live.untilShadow" : "live.untilSet")
        }
    }
    public var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                if !spaciousText { StationPassIcon(station: pass.station).frame(width: 36, height: 34) }
                VStack(alignment: .leading, spacing: 2) {
                    Text(text(pass.station == 25544 ? "iss.compact" : "tiangong")).font(.headline)
                    if !spaciousText, let key = statusKey {
                        Text(text(key)).font(.caption2).foregroundStyle(MoonstonePalette.muted)
                    }
                }
                .lineLimit(2).minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 2) {
                    if stale { Text(pass.set, style: .time).font(.headline.monospacedDigit()) }
                    else { StationPassCountdown(pass: pass, state: state, previewDate: previewDate).font(.title3.monospacedDigit().weight(.semibold)) }
                    Text(label).font(.caption2).foregroundStyle(MoonstonePalette.muted).lineLimit(2).multilineTextAlignment(.trailing)
                }.fixedSize(horizontal: false, vertical: true)
            }
            .frame(minHeight: 34)
            arc.frame(height: spaciousText ? 58 : 68)
            HStack(spacing: 10) {
                if spaciousText, let key = statusKey { Text(text(key)).lineLimit(1).minimumScaleFactor(0.8) }
                else {
                    legend("live.sunlit", dashed: false)
                    if pass.hasShadow { legend("live.shadow", dashed: true) }
                }
                Spacer(minLength: 0)
            }.font(.caption2).foregroundStyle(MoonstonePalette.muted).dynamicTypeSize(...DynamicTypeSize.large)
        }
        .foregroundStyle(MoonstonePalette.text)
        .padding(.horizontal, 16).padding(.vertical, spaciousText ? 6 : 10)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
    private func legend(_ key: String, dashed: Bool) -> some View {
        HStack(spacing: 4) {
            Path { $0.move(to: .init(x: 0, y: 3)); $0.addLine(to: .init(x: 14, y: 3)) }
                .stroke(dashed ? MoonstonePalette.muted : MoonstonePalette.accent, style: .init(lineWidth: 2, dash: dashed ? [3, 3] : []))
                .frame(width: 14, height: 6).accessibilityHidden(true)
            Text(text(key)).lineLimit(1)
        }
    }
    private var arc: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let duration = max(1, pass.set.timeIntervalSince(pass.rise))
            ZStack(alignment: .topLeading) {
                Canvas { ctx, size in
                    let position: (Double, Double) -> CGPoint = { seconds, elevation in
                        CGPoint(x: 8 + (size.width - 16) * seconds / duration, y: size.height - 20 - min(90, max(0, elevation)) / 90 * max(8, size.height - 33))
                    }
                    var horizon = Path(); horizon.move(to: .init(x: 8, y: size.height - 20)); horizon.addLine(to: .init(x: size.width - 8, y: size.height - 20))
                    ctx.stroke(horizon, with: .color(MoonstonePalette.muted.opacity(0.25)), lineWidth: 1)
                    // Split at exact shadow boundaries, including boundaries between sample points.
                    let transitions = pass.illuminated.flatMap { [$0.start.timeIntervalSince(pass.rise), $0.end.timeIntervalSince(pass.rise)] }
                    var paths: [(Path, Bool)] = []
                    var current = Path()
                    var previousLit: Bool?
                    for (a, b) in zip(pass.points, pass.points.dropFirst()) where b.seconds > a.seconds {
                        let cuts = ([Double(a.seconds), Double(b.seconds)] + transitions.filter { $0 > Double(a.seconds) && $0 < Double(b.seconds) }).sorted()
                        for (start, end) in zip(cuts, cuts.dropFirst()) {
                            func elevation(_ t: Double) -> Double { (Double(a.elevation) + Double(b.elevation - a.elevation) * (t - Double(a.seconds)) / Double(b.seconds - a.seconds)) / 10 }
                            let lit = pass.isIlluminated(at: pass.rise.addingTimeInterval((start + end) / 2))
                            if previousLit != lit {
                                if let previousLit { paths.append((current, previousLit)) }
                                current = Path(); current.move(to: position(start, elevation(start)))
                                previousLit = lit
                            }
                            current.addLine(to: position(end, elevation(end)))
                        }
                    }
                    if let previousLit { paths.append((current, previousLit)) }
                    for (path, lit) in paths {
                        ctx.stroke(path, with: .color(lit ? MoonstonePalette.accent : MoonstonePalette.muted), style: .init(lineWidth: lit ? 2.5 : 1.5, lineCap: .round, lineJoin: .round, dash: lit ? [] : [3, 3]))
                    }
                }.accessibilityHidden(true)
                Text(String(format: text("live.peak"), locale: locale, pass.peak))
                    .font(.caption2.weight(.semibold)).frame(width: width, alignment: .center)
                HStack {
                    Text(text(pass.startDirection) + " · 0°")
                    Spacer()
                    Text(text(pass.endDirection) + " · 0°")
                }.font(.caption2).foregroundStyle(MoonstonePalette.muted).offset(y: geometry.size.height - 18)
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.large)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(format: text("live.arcAccessibility"), locale: locale,
            text(pass.startDirection), text(pass.endDirection), pass.peak))
    }
}

public struct StationPassIcon: View {
    public let station: Int
    public init(station: Int) { self.station = station }
    public var body: some View {
        Image(station == 25544 ? "station_iss" : "station_tiangong", bundle: .module)
            .resizable().scaledToFit().accessibilityHidden(true)
    }
}
public struct StationPassCountdown: View {
    public let pass: StationPassActivity
    public let state: StationPassActivity.ContentState
    public var previewDate: Date?
    public init(pass: StationPassActivity, state: StationPassActivity.ContentState, previewDate: Date? = nil) {
        self.pass = pass; self.state = state; self.previewDate = previewDate
    }
    public var body: some View {
        if state.phase == .ended { Image(systemName: "checkmark") }
        else if let date = previewDate {
            let seconds = max(0, Int(state.target.timeIntervalSince(date)))
            Text(verbatim: String(format: "%d:%02d", seconds / 60, seconds % 60))
        } else {
            Text(timerInterval: min(pass.rise.addingTimeInterval(-600), state.target)...state.target, countsDown: true, showsHours: false)
                .monospacedDigit().multilineTextAlignment(.trailing).frame(maxWidth: 70)
        }
    }
}
