import SwiftUI
import WidgetKit

/// Shares the main app's navy surfaces, teal accent, muted labels and rounded typography.
public struct StationWidgetView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @Environment(\.timeZone) private var timeZone
    public let forecast: WidgetForecast?
    public let date: Date
    public let family: WidgetFamily
    public let chart: Bool
    public let station: Int
    private let accent = Color(red: 112/255, green: 218/255, blue: 210/255)
    private let muted = Color(red: 167/255, green: 184/255, blue: 203/255)
    public static let background = Color(red: 10/255, green: 19/255, blue: 33/255)
    /// Margins applied by the host in place of the system's 16 pt content inset. The
    /// medium rows use 10 pt top and bottom so the two rows fill the widget height.
    public static func contentPadding(for family: WidgetFamily) -> EdgeInsets {
        family == .systemMedium ? EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
            : EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
    }

    public init(forecast: WidgetForecast?, date: Date, family: WidgetFamily, chart: Bool = false, station: Int = 25544) {
        self.forecast = forecast
        self.date = date
        self.family = family
        self.chart = chart
        self.station = station
    }
    private func text(_ key: String) -> String { WidgetStrings.text(key, locale: locale) }
    private func stationName(_ station: Int) -> String { text(station == 25544 ? "iss.compact" : "tiangong") }
    private var spaciousText: Bool { dynamicTypeSize > .large }
    private var valid: Bool { forecast.map { date >= $0.generated && date < $0.expires } ?? false }
    public var body: some View {
        VStack(alignment: .leading, spacing: spaciousText || family == .systemSmall ? 5 : (family == .systemLarge ? 6 : 10)) {
            if !valid {
                Spacer(minLength: 0)
                if family != .systemSmall { Image(systemName: "location.circle").font(.title2).foregroundStyle(accent) }
                Text(text(forecast == nil ? "setup" : "refresh"))
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .lineLimit(3).minimumScaleFactor(0.75)
                Text(text("open.short")).font(.caption).foregroundStyle(muted)
                    .lineLimit(2).minimumScaleFactor(0.75)
                Spacer(minLength: 0)
            } else if family == .systemLarge {
                skyChartContent
            } else if family == .systemSmall && chart {
                chartContent
            } else {
                stationRows
            }
        }
        // Widget viewports are fixed; retain readable scaling through XXXL while
        // keeping complete text available to VoiceOver at accessibility settings.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: Two-row layouts

    /// Small: the sooner pass leads with a large time and a "when · where · how long" line;
    /// the other station sits in a compact footer. Medium: one list row per station, the
    /// elevation on the arc rather than beside the name.
    @ViewBuilder private var stationRows: some View {
        let iss = forecast?.next(station: 25544, at: date)
        let tiangong = forecast?.next(station: 48274, at: date)
        if family == .systemSmall {
            let ordered: [(Int, WidgetPass?)] = (iss?.rise ?? .distantFuture) <= (tiangong?.rise ?? .distantFuture)
                ? [(25544, iss), (48274, tiangong)] : [(48274, tiangong), (25544, iss)]
            VStack(alignment: .leading, spacing: 0) {
                featured(station: ordered[0].0, pass: ordered[0].1)
                Spacer(minLength: 6)
                Rectangle().fill(muted.opacity(0.18)).frame(height: 1)
                footer(station: ordered[1].0, pass: ordered[1].1).padding(.top, 8)
            }
        } else {
            GeometryReader { proxy in
                // The arc needs the regular medium width; 292 pt widgets give the space to text.
                let compact = proxy.size.width < 300
                VStack(spacing: 0) {
                    mediumRow(station: 25544, pass: iss, compact: compact)
                    Rectangle().fill(muted.opacity(0.18)).frame(height: 1).padding(.leading, 52)
                    mediumRow(station: 48274, pass: tiangong, compact: compact)
                }
            }
        }
    }

    private func icon(_ station: Int, size: CGFloat) -> some View {
        Image(station == 25544 ? "station_iss" : "station_tiangong", bundle: .module)
            .resizable().aspectRatio(contentMode: .fit).frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    /// Filled at 40° and above, outlined below, matching the app's pass list.
    private func elevationChip(_ pass: WidgetPass, compact: Bool = false) -> some View {
        let degrees = Int(pass.elevation.rounded())
        let strong = degrees >= 40
        return Text(verbatim: "\(degrees)°")
            .font(.system(size: compact ? 10 : 11, weight: .bold, design: .rounded)).monospacedDigit()
            .foregroundStyle(strong ? Self.background : accent)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(strong ? accent : accent.opacity(0.16), in: Capsule())
            .accessibilityLabel("\(degrees) degrees maximum")
    }

    /// nil while the pass is in progress: the time slot already says so.
    private func dayLabel(_ pass: WidgetPass) -> String? {
        if pass.rise <= date { return nil }
        if calendar.isDate(pass.rise, inSameDayAs: date) {
            return text(calendar.component(.hour, from: pass.rise) >= 18 ? "tonight" : "today")
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: date), calendar.isDate(pass.rise, inSameDayAs: tomorrow) {
            return text("tomorrow")
        }
        var format = Date.FormatStyle().month(.abbreviated).day()
        format.locale = locale; format.calendar = calendar; format.timeZone = timeZone
        return pass.rise.formatted(format)
    }
    private func clock(_ pass: WidgetPass) -> Text {
        var format = Date.FormatStyle().hour().minute()
        format.locale = locale; format.calendar = calendar; format.timeZone = timeZone
        return Text(pass.rise.formatted(format))
    }
    private func minutes(_ pass: WidgetPass) -> String {
        String(format: text("minutes"), locale: locale, max(1, Int((pass.set.timeIntervalSince(pass.rise) / 60).rounded())))
    }
    /// "NW → SE · 7 min" with the localized compass points.
    private func route(_ pass: WidgetPass) -> String {
        "\(text(pass.startDirection)) → \(text(pass.endDirection)) · \(minutes(pass))"
    }

    private func featured(station: Int, pass: WidgetPass?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                icon(station, size: 22)
                Text(stationName(station)).accessibilityLabel(text(station == 25544 ? "iss" : "tiangong"))
                    .font(.system(.subheadline, design: .rounded, weight: .bold)).lineLimit(1).minimumScaleFactor(0.6)
                Spacer(minLength: 4)
                if let pass { elevationChip(pass).fixedSize().layoutPriority(1) }
            }
            if let pass {
                if pass.rise <= date {
                    Text(text("now.short")).font(.system(.title3, design: .rounded, weight: .bold)).foregroundStyle(accent)
                        .lineLimit(1).minimumScaleFactor(0.6)
                } else {
                    clock(pass).font(.system(size: 26, weight: .bold, design: .rounded)).monospacedDigit()
                        .lineLimit(1).minimumScaleFactor(0.6)
                }
                // Small has no room for the compass route; day and duration only.
                Text([dayLabel(pass), minutes(pass)].compactMap { $0 }.joined(separator: " · ")).font(.system(size: 11)).foregroundStyle(muted)
                    .lineLimit(1).minimumScaleFactor(0.8)
            } else {
                Text(text("empty.short")).font(.subheadline).foregroundStyle(muted).lineLimit(2).minimumScaleFactor(0.75)
            }
        }
    }

    private func footerTime(_ pass: WidgetPass, showsDay: Bool) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            if pass.rise <= date {
                Text(text("now.short")).foregroundStyle(accent).font(.system(size: 12.5, weight: .semibold, design: .rounded))
            } else {
                clock(pass).font(.system(size: 12.5, weight: .semibold, design: .rounded)).monospacedDigit()
                if showsDay, let day = dayLabel(pass) { Text(day).font(.system(size: 10)).foregroundStyle(muted) }
            }
        }
        .lineLimit(1).fixedSize(horizontal: showsDay, vertical: true)
    }

    private func footer(station: Int, pass: WidgetPass?) -> some View {
        HStack(spacing: 6) {
            icon(station, size: 18)
            if pass == nil {
                Text(stationName(station)).accessibilityLabel(text(station == 25544 ? "iss" : "tiangong"))
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.6)
                Spacer(minLength: 4)
            }
            if let pass {
                // Stacked time and day when the name leaves room; time alone when it does not.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 4) {
                        Text(stationName(station)).font(.system(size: 12.5, weight: .semibold, design: .rounded)).lineLimit(1).fixedSize()
                        Spacer(minLength: 6)
                        footerTime(pass, showsDay: true)
                    }
                    // Tight rows keep the whole name and let the clock shrink instead.
                    HStack(spacing: 4) {
                        Text(stationName(station)).font(.system(size: 12.5, weight: .semibold, design: .rounded)).lineLimit(1).fixedSize()
                        Spacer(minLength: 4)
                        footerTime(pass, showsDay: false).minimumScaleFactor(0.55)
                    }
                }
                .accessibilityLabel(text(station == 25544 ? "iss" : "tiangong"))
            } else {
                Text(text("empty.short")).font(.system(size: 11)).foregroundStyle(muted).lineLimit(1).minimumScaleFactor(0.7)
            }
        }
    }

    private func mediumRow(station: Int, pass: WidgetPass?, compact: Bool) -> some View {
        HStack(spacing: 10) {
            icon(station, size: 42)
            VStack(alignment: .leading, spacing: 4) {
                Text(stationName(station)).accessibilityLabel(text(station == 25544 ? "iss" : "tiangong"))
                    .font(.system(size: 17, weight: .bold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.7)
                if let pass {
                    Text(route(pass)).font(.system(size: 12.5)).foregroundStyle(muted).lineLimit(1).minimumScaleFactor(0.75)
                } else {
                    Text(text("empty")).font(.system(size: 12.5)).foregroundStyle(muted).lineLimit(1).minimumScaleFactor(0.75)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let pass {
                VStack(alignment: .trailing, spacing: 4) {
                    if pass.rise <= date {
                        Text(text("now.short")).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(accent)
                    } else {
                        clock(pass).font(.system(size: 21, weight: .bold, design: .rounded)).monospacedDigit()
                    }
                    if let day = dayLabel(pass) { Text(day).font(.system(size: 12)).foregroundStyle(muted) }
                }
                .lineLimit(1).minimumScaleFactor(0.6).layoutPriority(1)
                if !spaciousText && !compact {
                    Group {
                        if let dome = pass.dome {
                            DomeChart(pass: pass, dome: dome, accent: accent, muted: muted, showsBackground: false, labelSize: 0)
                        } else {
                            PassArc(pass: pass, accent: accent, muted: muted, showsLabels: false)
                        }
                    }
                    .frame(width: 92, height: 56)
                    .accessibilityLabel("\(Int(pass.elevation.rounded())) degrees maximum, \(text(pass.startDirection)) to \(text(pass.endDirection))")
                }
            }
        }
        .frame(maxHeight: .infinity)
    }


    /// Small chart: the two-row small's hierarchy with the dome in place of the footer.
    @ViewBuilder private var chartContent: some View {
        let pass = forecast?.next(station: station, at: date)
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                icon(station, size: 20)
                Text(stationName(station)).accessibilityLabel(text(station == 25544 ? "iss" : "tiangong"))
                    .font(.system(.subheadline, design: .rounded, weight: .bold)).lineLimit(1).minimumScaleFactor(0.6)
                Spacer(minLength: 4)
                if let pass { elevationChip(pass).fixedSize().layoutPriority(1) }
            }
            if let pass {
                Group {
                    if pass.rise <= date {
                        Text(text("now.short")).font(.system(.title3, design: .rounded, weight: .bold)).foregroundStyle(accent)
                    } else {
                        clock(pass).font(.system(size: 24, weight: .bold, design: .rounded)).monospacedDigit()
                    }
                }
                .lineLimit(1).minimumScaleFactor(0.6).padding(.top, 4)
                Text([dayLabel(pass), minutes(pass)].compactMap { $0 }.joined(separator: " · ")).font(.system(size: 11)).foregroundStyle(muted)
                    .lineLimit(1).minimumScaleFactor(0.8)
                Spacer(minLength: 2)
                Group {
                    if let dome = pass.dome {
                        DomeChart(pass: pass, dome: dome, accent: accent, muted: muted, labelSize: 9, showsPeakLabel: false)
                    } else {
                        PassArc(pass: pass, accent: accent, muted: muted, showsPeakLabel: false)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: spaciousText ? 44 : 56)
                .padding(.horizontal, -4)
                .accessibilityLabel("Sky preview, \(text(pass.startDirection)) to \(text(pass.endDirection))")
            } else {
                Spacer(minLength: 0)
                Text(text("empty.short")).font(.subheadline).foregroundStyle(muted).lineLimit(3).minimumScaleFactor(0.75)
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder private var skyChartContent: some View {
        if let pass = forecast?.next(at: date) {
            HStack(alignment: .center, spacing: 10) {
                icon(pass.station, size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(stationName(pass.station)).accessibilityLabel(text(pass.station == 25544 ? "iss" : "tiangong"))
                        .font(.system(size: 20, weight: .bold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.6)
                    Text([dayLabel(pass), minutes(pass)].compactMap { $0 }.joined(separator: " · "))
                        .font(.system(size: 12.5)).foregroundStyle(muted).lineLimit(1).minimumScaleFactor(0.75)
                }
                Spacer(minLength: 8)
                Group {
                    if pass.rise <= date {
                        Text(text("now.short"))
                    } else {
                        clock(pass).monospacedDigit()
                    }
                }
                .font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(accent)
                .lineLimit(1).minimumScaleFactor(0.6).layoutPriority(1)
            }
            if let track = pass.skyTrack, track.count >= 2 {
                WidgetSkyChart(track: track, background: pass.skyBackground, events: pass.events ?? [],
                               peakElevation: pass.elevation, accent: accent, muted: muted)
                    .padding(.horizontal, -8)
                    .padding(.bottom, -8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel("North-up sky chart. \(pass.name), \(pass.startDirection) to \(pass.endDirection), maximum elevation \(Int(pass.elevation.rounded())) degrees. East is on the left.")
            } else {
                Spacer(minLength: 0)
                Image(systemName: "sparkles").font(.largeTitle).foregroundStyle(accent)
                Text(text("load")).font(.subheadline).foregroundStyle(muted)
                Spacer(minLength: 0)
            }
        } else {
            Spacer(minLength: 0)
            Image(systemName: "moon.stars").font(.largeTitle).foregroundStyle(accent)
            Text(text("empty.large")).font(.headline)
            Text(text("empty.detail")).font(.subheadline).foregroundStyle(muted)
            Spacer(minLength: 0)
        }
    }

    private func time(_ pass: WidgetPass) -> some View {
        Group {
            if pass.rise <= date {
                Text(text("now.short")).foregroundStyle(accent).accessibilityLabel(text("now"))
            } else if calendar.isDate(pass.rise, inSameDayAs: date) {
                Text(pass.rise, style: .time)
            } else {
                Text(compactDateTime(pass.rise))
            }
        }
        .lineLimit(1).minimumScaleFactor(0.65)
    }

    private func compactDateTime(_ date: Date) -> String {
        var format = Date.FormatStyle().month(.defaultDigits).day().hour().minute()
        format.locale = locale
        format.calendar = calendar
        format.timeZone = timeZone
        return date.formatted(format)
    }

}

/// Elevation over time for one pass. Sunlit portions are teal and shadowed portions grey,
/// taken from the sky track; the peak carries its elevation in degrees.
private struct PassArc: View {
    @Environment(\.locale) private var locale
    let pass: WidgetPass
    let accent: Color
    let muted: Color
    var showsLabels = true
    var showsPeakLabel = true

    /// (fraction of pass, elevation 0–90, illuminated) samples; a symmetric arc when no track exists.
    private var samples: [(x: Double, elevation: Double, lit: Bool)] {
        if let track = pass.skyTrack, track.count >= 2 {
            return track.enumerated().map { (Double($0.offset) / Double(track.count - 1), $0.element.elevation, $0.element.illuminated) }
        }
        let peak = min(0.9, max(0.1, pass.peak.timeIntervalSince(pass.rise) / max(1, pass.set.timeIntervalSince(pass.rise))))
        return (0...40).map { i in
            let x = Double(i) / 40
            let t = x < peak ? x / peak : (1 - x) / (1 - peak)
            return (x, pass.elevation * sin(t * .pi / 2), true)
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            Canvas { context, size in
                let w = size.width, h = size.height
                let top: CGFloat = 12   // room for the peak label
                func point(_ s: (x: Double, elevation: Double, lit: Bool)) -> CGPoint {
                    CGPoint(x: 2 + (w - 4) * s.x, y: h - (h - top) * min(90, max(0, s.elevation)) / 90)
                }
                var horizon = Path()
                horizon.move(to: CGPoint(x: 0, y: h)); horizon.addLine(to: CGPoint(x: w, y: h))
                context.stroke(horizon, with: .color(muted.opacity(0.35)), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                let samples = samples
                // Contiguous runs share illumination; grey runs sit underneath teal ones.
                for lit in [false, true] {
                    var path = Path()
                    var connected = false
                    for i in 0..<(samples.count - 1) {
                        guard samples[i].lit == lit else { connected = false; continue }
                        if !connected { path.move(to: point(samples[i])) }
                        path.addLine(to: point(samples[i + 1]))
                        connected = true
                    }
                    context.stroke(path, with: .color(lit ? accent : muted.opacity(0.7)),
                                   style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round,
                                                      dash: lit ? [] : [2, 4]))
                }
                if let peak = samples.max(by: { $0.elevation < $1.elevation }) {
                    let p = point(peak)
                    context.fill(Path(ellipseIn: CGRect(x: p.x - 2.5, y: p.y - 2.5, width: 5, height: 5)),
                                 with: .color(peak.lit ? accent : muted))
                    if showsPeakLabel {
                        let label = Text("\(Int(pass.elevation.rounded()))°")
                            .font(.system(size: 10, weight: .semibold, design: .rounded)).foregroundStyle(accent)
                        let anchor = CGPoint(x: min(w - 12, max(12, p.x)), y: max(6, p.y - 9))
                        context.draw(label, at: anchor)
                    }
                }
            }
            if showsLabels {
                HStack {
                    Text(WidgetStrings.text(pass.startDirection, locale: locale))
                    Spacer()
                    Text(WidgetStrings.text(pass.endDirection, locale: locale))
                }.font(.system(size: 9, weight: .medium)).foregroundStyle(muted)
            }
        }
    }
}


/// The home screen's rise-to-set dome: the app-rendered sky with the projected track,
/// dotted horizon, peak elevation and compass labels, scaled to the widget. The dome is
/// fitted so the horizon sits just above the compass labels and the arc fills the width.
private struct DomeChart: View {
    @Environment(\.locale) private var locale
    let pass: WidgetPass
    let dome: WidgetDome
    let accent: Color
    let muted: Color
    var showsBackground = true
    var labelSize: CGFloat = 9
    var showsPeakLabel = true

    var body: some View {
        GeometryReader { proxy in
            // labelSize 0 hides the compass labels; the peak degrees stay on the arc.
            let labelHeight: CGFloat = labelSize > 0 ? labelSize + 4 : 0
            let track = dome.track
            let peakY = track.map(\.y).min() ?? 0.2
            let horizonY = max(track.first?.y ?? 0.8, track.last?.y ?? 0.8)
            let peakLabelRoom: CGFloat = showsPeakLabel ? 16 : 4
            let usableHeight = max(1, proxy.size.height - labelHeight - peakLabelRoom - 2)
            let span = max(0.05, horizonY - peakY) * dome.height
            let scale = min(proxy.size.width / dome.width, usableHeight / span)
            // Centre the used band (peak label, arc, compass labels) vertically.
            let used = peakLabelRoom + span * scale + labelHeight + 2
            let top = max(0, (proxy.size.height - used) / 2)
            let rect = CGRect(x: (proxy.size.width - dome.width * scale) / 2,
                              y: top + peakLabelRoom - peakY * dome.height * scale,
                              width: dome.width * scale, height: dome.height * scale)
            let point: (WidgetDomePoint) -> CGPoint = { p in CGPoint(x: rect.minX + p.x * rect.width, y: rect.minY + p.y * rect.height) }
            let horizonLine = rect.minY + horizonY * rect.height
            ZStack(alignment: .topLeading) {
                if showsBackground, let data = dome.imagePNG, let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().frame(width: rect.width, height: rect.height).offset(x: rect.minX, y: rect.minY)
                }
                Canvas { context, _ in
                    var horizon = Path()
                    for (i, p) in dome.horizon.enumerated() { i == 0 ? horizon.move(to: point(p)) : horizon.addLine(to: point(p)) }
                    context.stroke(horizon, with: .color(muted.opacity(0.6)), style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [1, 4]))
                    for lit in [false, true] {
                        var path = Path()
                        var connected = false
                        for i in 0..<max(0, track.count - 1) {
                            guard track[i].illuminated == lit else { connected = false; continue }
                            if !connected { path.move(to: point(track[i])) }
                            path.addLine(to: point(track[i + 1]))
                            connected = true
                        }
                        let style = StrokeStyle(lineWidth: lit ? 2.4 : 2, lineCap: .round, lineJoin: .round, dash: lit ? [] : [2, 4])
                        if showsBackground {
                            context.stroke(path, with: .color(.black.opacity(0.5)), style: StrokeStyle(lineWidth: style.lineWidth + 2, lineCap: .round, lineJoin: .round, dash: style.dash))
                        }
                        context.stroke(path, with: .color(lit ? accent : muted.opacity(0.85)), style: style)
                    }
                    if let peak = track.min(by: { $0.y < $1.y }) {
                        let p = point(peak)
                        context.fill(Path(ellipseIn: CGRect(x: p.x - 2.5, y: p.y - 2.5, width: 5, height: 5)), with: .color(peak.illuminated ? accent : muted))
                    }
                    if showsPeakLabel, let peak = track.min(by: { $0.y < $1.y }) {
                        let p = point(peak)
                        let label = context.resolve(Text("\(Int(pass.elevation.rounded()))°")
                            .font(.system(size: max(10, labelSize + 1), weight: .semibold, design: .rounded)).foregroundStyle(accent))
                        let size = label.measure(in: CGSize(width: 60, height: 20))
                        let anchor = CGPoint(x: min(proxy.size.width - size.width / 2, max(size.width / 2, p.x)), y: max(size.height / 2, p.y - 9))
                        if showsBackground {
                            context.fill(Path(roundedRect: CGRect(x: anchor.x - size.width / 2 - 3, y: anchor.y - size.height / 2 - 1, width: size.width + 6, height: size.height + 2), cornerRadius: 4),
                                         with: .color(.black.opacity(0.45)))
                        }
                        context.draw(label, at: anchor)
                    }
                    let labelY = min(proxy.size.height - labelHeight / 2, horizonLine + labelHeight / 2 + 2)
                    if labelSize > 0, let first = track.first, let last = track.last {
                        let font = Font.system(size: labelSize, weight: .medium, design: .rounded)
                        context.draw(Text(WidgetStrings.text(pass.startDirection, locale: locale)).font(font).foregroundStyle(muted),
                                     at: CGPoint(x: min(proxy.size.width - 8, max(8, point(first).x)), y: labelY))
                        context.draw(Text(WidgetStrings.text(pass.endDirection, locale: locale)).font(font).foregroundStyle(muted),
                                     at: CGPoint(x: min(proxy.size.width - 8, max(8, point(last).x)), y: labelY))
                    }
                }
            }
            .clipped()
        }
    }
}

/// A compact horizon-to-zenith chart using the same projection as SkyChartUtils.
private struct WidgetSkyChart: View {
    @Environment(\.locale) private var locale
    @Environment(\.timeZone) private var timeZone
    let track: [WidgetSkyPoint]
    let background: WidgetSkyBackground?
    let events: [WidgetSkyEvent]
    let peakElevation: Double
    let accent: Color
    let muted: Color

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = max(1, min(size.width, size.height) / 2 - 17)
            func label(_ text: String, at position: CGPoint, color: Color = .white, size: CGFloat = 11) {
                context.draw(Text(text).font(.system(size: size, weight: .medium, design: .rounded))
                    .foregroundStyle(color), at: position)
            }
            let disk = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            let diskPath = Path(ellipseIn: disk)
            var sky = context
            sky.clip(to: diskPath)
            // Same deep-blue zenith, violet horizon and solar-side twilight as SkyChartAtmosphere.
            let sunElevation = background?.sun.elevation ?? -24
            func transition(_ low: Double, _ high: Double, _ value: Double) -> Double {
                let t = min(1, max(0, (value - low) / (high - low)))
                return t * t * (3 - 2 * t)
            }
            let twilight = transition(-18, -5, sunElevation) * (1 - transition(0, 14, sunElevation))
            sky.fill(diskPath, with: .radialGradient(Gradient(stops: [
                .init(color: Color(red: 0.025, green: 0.045, blue: 0.10), location: 0),
                .init(color: Color(red: 0.055, green: 0.10, blue: 0.19), location: 0.70),
                .init(color: Color(red: 0.13, green: 0.14, blue: 0.25), location: 1)
            ]), center: center, startRadius: 0, endRadius: radius))
            sky.fill(diskPath, with: .radialGradient(Gradient(stops: [
                .init(color: .clear, location: 0.45),
                .init(color: Color(red: 0.27, green: 0.16, blue: 0.65).opacity(twilight * 0.25), location: 0.76),
                .init(color: Color(red: 0.65, green: 0.27, blue: 0.78).opacity(twilight * 0.6), location: 1)
            ]), center: center, startRadius: 0, endRadius: radius))
            if let sun = background?.sun {
                let angle = sun.azimuth * .pi / 180
                let distance = (90 - sun.elevation) / 90 * radius
                let position = CGPoint(x: center.x - sin(angle) * distance, y: center.y - cos(angle) * distance)
                sky.fill(diskPath, with: .radialGradient(Gradient(colors: [
                    Color(red: 1, green: 0.45, blue: 0.25).opacity(twilight * 0.45), .clear
                ]), center: position, startRadius: 0, endRadius: radius * 1.1))
            }
            if let data = background?.imagePNG, let image = UIImage(data: data) {
                sky.draw(Image(uiImage: image), in: disk)
            }
            context.stroke(diskPath, with: .color(muted.opacity(0.55)), lineWidth: 0.8)
            var ticks = Path()
            for degrees in stride(from: 0.0, to: 360.0, by: 15) {
                let angle = degrees * .pi / 180
                let length = Int(degrees) % 45 == 0 ? 4.0 : 2.0
                ticks.move(to: CGPoint(x: center.x - sin(angle) * radius, y: center.y - cos(angle) * radius))
                ticks.addLine(to: CGPoint(x: center.x - sin(angle) * (radius + length), y: center.y - cos(angle) * (radius + length)))
            }
            context.stroke(ticks, with: .color(muted.opacity(0.45)), lineWidth: 0.6)
            label(WidgetStrings.text("N", locale: locale), at: CGPoint(x: center.x, y: center.y - radius - 11), color: accent)
            label(WidgetStrings.text("S", locale: locale), at: CGPoint(x: center.x, y: center.y + radius + 11), color: muted)
            label(WidgetStrings.text("E", locale: locale), at: CGPoint(x: center.x - radius - 11, y: center.y), color: muted)
            label(WidgetStrings.text("W", locale: locale), at: CGPoint(x: center.x + radius + 11, y: center.y), color: muted)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 2
            let pathImage = UIGraphicsImageRenderer(size: disk.size, format: format).image { rendered in
                SkyPassPathRenderer.draw(in: rendered.cgContext, rect: CGRect(origin: .zero, size: disk.size),
                    track: track, lineWidth: 1.5, illuminatedColor: UIColor(accent),
                    unlitColor: UIColor(muted).withAlphaComponent(0.6))
            }
            sky.draw(Image(uiImage: pathImage), in: disk)
            drawEvents(in: &context, center: center, radius: radius)
        }
    }

    /// Timestamps at rise, culmination, set and shadow crossings. The peak also carries its
    /// elevation. Labels sit on the side of the marker that faces away from the chart centre,
    /// which keeps them off the track and inside the disk for most passes.
    private func drawEvents(in context: inout GraphicsContext, center: CGPoint, radius: CGFloat) {
        let style = Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, timeZone: timeZone)
        struct Placed { let event: WidgetSkyEvent; let point: CGPoint; var rect: CGRect; let text: GraphicsContext.ResolvedText }
        var placed: [Placed] = []
        for event in events {
            let unit = event.position.unitPoint
            let point = CGPoint(x: center.x + unit.x * radius, y: center.y + unit.y * radius)
            var label = event.date.formatted(style)
            if event.kind == .peak { label += " · \(Int(peakElevation.rounded()))°" }
            let resolved = context.resolve(Text(label).font(.system(size: 10, weight: .semibold, design: .rounded)).foregroundStyle(.white))
            let size = resolved.measure(in: CGSize(width: 120, height: 20))
            // Horizon events and anything near the rim go inward so the text stays on the disk;
            // the peak sits above its marker; the rest go outward, away from the track.
            let distance = hypot(unit.x, unit.y)
            let direction = distance > 0.001 ? CGPoint(x: unit.x / distance, y: unit.y / distance) : CGPoint(x: 0, y: -1)
            let inward = event.kind == .rise || event.kind == .set || distance > 0.8
            var anchor = CGPoint(x: point.x + direction.x * (inward ? -16 : 14), y: point.y + direction.y * (inward ? -16 : 14))
            if event.kind == .peak { anchor = CGPoint(x: point.x, y: point.y - 13) }
            let rect = CGRect(x: anchor.x - size.width / 2 - 4, y: anchor.y - size.height / 2 - 2, width: size.width + 8, height: size.height + 4)
            placed.append(.init(event: event, point: point, rect: rect, text: resolved))
        }
        // A shadow crossing within two minutes of the set or rise keeps its marker but not its
        // label; the neighbouring horizon label already tells the time.
        var labelled = Set(placed.indices)
        for i in placed.indices where placed[i].event.kind == .entersShadow || placed[i].event.kind == .exitsShadow {
            if placed.contains(where: { ($0.event.kind == .rise || $0.event.kind == .set) && abs($0.event.date.timeIntervalSince(placed[i].event.date)) < 120 }) {
                labelled.remove(i)
            }
        }
        // Resolve remaining overlaps by pushing the later label inward along its radius.
        for i in placed.indices where labelled.contains(i) {
            var attempts = 0
            while attempts < 8, (0..<i).contains(where: { labelled.contains($0) && placed[i].rect.intersects(placed[$0].rect) }) {
                let dx = center.x - placed[i].point.x, dy = center.y - placed[i].point.y
                let length = max(1, hypot(dx, dy))
                placed[i].rect = placed[i].rect.offsetBy(dx: dx / length * 12, dy: dy / length * 12)
                attempts += 1
            }
        }
        for (index, item) in placed.enumerated() {
            let shadow = item.event.kind == .entersShadow || item.event.kind == .exitsShadow
            let color = shadow ? muted : accent
            let marker = Path(ellipseIn: CGRect(x: item.point.x - 3, y: item.point.y - 3, width: 6, height: 6))
            context.fill(marker, with: .color(item.event.kind == .entersShadow ? muted.opacity(0.9) : Color.black.opacity(0.6)))
            context.stroke(marker, with: .color(color), lineWidth: 1.4)
            guard labelled.contains(index) else { continue }
            context.fill(Path(roundedRect: item.rect, cornerRadius: 5), with: .color(Color.black.opacity(0.55)))
            context.draw(item.text, at: CGPoint(x: item.rect.midX, y: item.rect.midY))
        }
    }
}

