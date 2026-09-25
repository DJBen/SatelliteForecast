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
                row(station: 25544)
                Rectangle().fill(muted.opacity(0.18)).frame(height: 1)
                row(station: 48274)
            }
        }
        // Widget viewports are fixed; retain readable scaling through XXXL while
        // keeping complete text available to VoiceOver at accessibility settings.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder private func row(station: Int) -> some View {
        let pass = forecast?.next(station: station, at: date)
        let small = family == .systemSmall
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: small || spaciousText ? 3 : 6) {
                HStack(spacing: 5) {
                    Circle().fill(accent).frame(width: 5, height: 5)
                    Text(stationName(station)).accessibilityLabel(text(station == 25544 ? "iss" : "tiangong"))
                        .font(.system(small ? .subheadline : .headline, design: .rounded, weight: .semibold))
                        .lineLimit(1).minimumScaleFactor(0.75)
                    if family == .systemMedium, let pass {
                        Spacer(minLength: 3)
                        time(pass).font(.system(.subheadline, design: .rounded, weight: .medium))
                    }
                }
                if let pass {
                    if family != .systemMedium {
                        time(pass).font(.system(small ? .caption : .title3, design: .rounded, weight: .medium))
                    }
                    if !small {
                        Text("\(Int(pass.elevation.rounded()))° \(text("max")) · \(text(pass.startDirection)) → \(text(pass.endDirection))")
                            .font(.caption).foregroundStyle(muted).lineLimit(1).minimumScaleFactor(0.7)
                    }
                } else {
                    Text(text(small ? "empty.short" : "empty")).font(.caption).foregroundStyle(muted)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if !small, !spaciousText, let pass, pass.rise > date, calendar.isDate(pass.rise, inSameDayAs: date) {
                PassArc(pass: pass, accent: accent, muted: muted)
                    .frame(width: family == .systemLarge ? 116 : 72, height: family == .systemLarge ? 88 : 42)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxHeight: .infinity, alignment: .center)
    }

    @ViewBuilder private var chartContent: some View {
        let pass = forecast?.next(station: station, at: date)
        HStack(spacing: 4) {
            Text(stationName(station)).accessibilityLabel(text(station == 25544 ? "iss" : "tiangong")).font(.system(.headline, design: .rounded))
                .lineLimit(1).minimumScaleFactor(0.5)
            Spacer(minLength: 6)
            if let pass { Text("\(Int(pass.elevation.rounded()))°").font(.caption.weight(.semibold)).foregroundStyle(accent).fixedSize() }
        }
        if let pass {
            PassArc(pass: pass, accent: accent, muted: muted).frame(maxHeight: .infinity)
                .accessibilityLabel("Simplified elevation chart, maximum \(Int(pass.elevation.rounded())) degrees")
            time(pass).font(.system(.caption, design: .rounded, weight: .medium))
        } else {
            Spacer(minLength: 0)
            Text(text("empty.short")).font(.subheadline).foregroundStyle(muted).lineLimit(3).minimumScaleFactor(0.75)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder private var skyChartContent: some View {
        if let pass = forecast?.next(at: date) {
            HStack(alignment: .firstTextBaseline) {
                Text(stationName(pass.station)).accessibilityLabel(text(pass.station == 25544 ? "iss" : "tiangong")).font(.system(.title2, design: .rounded, weight: .semibold))
                    .lineLimit(1).minimumScaleFactor(0.75)
                Spacer(minLength: 8)
                time(pass).font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(accent)
            }
            if let track = pass.skyTrack, track.count >= 2 {
                WidgetSkyChart(track: track, background: pass.skyBackground, accent: accent, muted: muted)
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

private struct PassArc: View {
    @Environment(\.locale) private var locale
    let pass: WidgetPass
    let accent: Color
    let muted: Color
    var body: some View {
        VStack(spacing: 3) {
            GeometryReader { proxy in
                let w = proxy.size.width
                let h = proxy.size.height
                let peak = min(0.9, max(0.1, pass.peak.timeIntervalSince(pass.rise) / pass.set.timeIntervalSince(pass.rise)))
                let y = h * (1 - min(90, max(0, pass.elevation)) / 90) * 0.8 + 2
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h))
                    p.addLine(to: CGPoint(x: w, y: h))
                    p.move(to: CGPoint(x: 0, y: h * 0.5))
                    p.addLine(to: CGPoint(x: w, y: h * 0.5))
                }.stroke(muted.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                Path { p in
                    p.move(to: CGPoint(x: 2, y: h))
                    p.addQuadCurve(to: CGPoint(x: w * peak, y: y), control: CGPoint(x: w * peak * 0.45, y: y))
                    p.addQuadCurve(to: CGPoint(x: w - 2, y: h), control: CGPoint(x: w * (peak + (1 - peak) * 0.55), y: y))
                }.stroke(accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                Circle().fill(accent).frame(width: 5, height: 5).position(x: w * peak, y: y)
            }
            HStack {
                Text(WidgetStrings.text(pass.startDirection, locale: locale))
                Spacer()
                Text(WidgetStrings.text(pass.endDirection, locale: locale))
            }.font(.system(size: 9, weight: .medium)).foregroundStyle(muted)
        }
    }
}


/// A compact horizon-to-zenith chart using the same projection as SkyChartUtils.
private struct WidgetSkyChart: View {
    @Environment(\.locale) private var locale
    let track: [WidgetSkyPoint]
    let background: WidgetSkyBackground?
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
        }
    }
}
