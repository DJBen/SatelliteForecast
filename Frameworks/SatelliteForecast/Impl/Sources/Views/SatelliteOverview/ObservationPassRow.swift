import SwiftUI
import SatelliteForecast
import SatelliteKit

/// One upcoming station pass, shared by the home "Coming up" list and the All passes screen.
/// The glass station icon distinguishes ISS from Tiangong before the name is read.
struct ObservationPassRow: View {
    let pass: Pass
    let now: Double
    /// Home rows carry the day; the All passes screen groups by day already.
    var showsDay = true
    let action: () -> Void
    @Environment(\.locale) private var locale
    @Environment(\.timeZone) private var timeZone
    @Environment(\.dynamicTypeSize) private var dynamicType

    private var start: Date { Date(julianDate: ObservationOpportunity.start(pass)) }
    private var elevation: Int { Int((pass.highestIlluminated?.elev ?? pass.culmination.elev).rounded()) }
    private var minutes: Int { max(1, Int((PassPreviewCell.visibleDurationSeconds(for: pass) / 60).rounded())) }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 14) {
                ObservationStationIcon(pass: pass)
                    .frame(width: dynamicType.isAccessibilitySize ? 40 : 52, height: dynamicType.isAccessibilitySize ? 40 : 52)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(ObservationOpportunity.shortName(pass)).font(.headline).foregroundStyle(AppTheme.text)
                        ObservationElevationBadge(degrees: elevation)
                    }
                    HStack(spacing: 5) {
                        Text(ObservationOpportunity.direction(pass.rise.azim))
                        Image(systemName: "arrow.right").font(.caption2.weight(.bold))
                        Text(ObservationOpportunity.direction(pass.set.azim))
                        Text(verbatim: "·")
                        Text(AppLocalization.format("%d min", minutes))
                    }
                    .font(.subheadline).foregroundStyle(AppTheme.muted).lineLimit(1)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 5) {
                    Text(start, format: .dateTime.hour().minute())
                        .font(.system(.headline, design: .rounded, weight: .semibold)).foregroundStyle(AppTheme.text)
                    if showsDay {
                        Text(ObservationPassRow.dayLabel(start, now: now, locale: locale, timeZone: timeZone, short: true))
                            .font(.caption).foregroundStyle(AppTheme.muted)
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: "\(ObservationOpportunity.name(pass)), \(start.formatted(date: .abbreviated, time: .shortened)), \(PassPreviewCell.visibleDurationText(for: pass, locale: locale))"))
        .accessibilityHint(Text("Opens the sky chart for this pass", bundle: .module))
    }

    static func dayLabel(_ target: Date, now: Double, locale: Locale, timeZone: TimeZone, short: Bool = false) -> String {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = timeZone
        let current = Date(julianDate: now)
        if calendar.isDate(target, inSameDayAs: current) {
            return AppLocalization.text(calendar.component(.hour, from: target) >= 18 ? "Tonight" : "Today")
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: current), calendar.isDate(target, inSameDayAs: tomorrow) {
            return AppLocalization.text("Tomorrow")
        }
        if short {
            return target.formatted(Date.FormatStyle(locale: locale, timeZone: timeZone).month(.abbreviated).day())
        }
        return target.formatted(Date.FormatStyle(locale: locale, timeZone: timeZone).weekday(.abbreviated).month(.abbreviated).day())
    }
}

/// Peak elevation as a compact capsule. Higher passes are brighter so the list scans by quality.
struct ObservationElevationBadge: View {
    let degrees: Int
    var body: some View {
        let strong = degrees >= 40
        Text(verbatim: "\(degrees)°")
            .font(.system(.footnote, design: .rounded, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(strong ? Color(uiColor: .systemBackground) : AppTheme.accent)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(strong ? AppTheme.accent : AppTheme.accent.opacity(0.14), in: Capsule())
            .accessibilityLabel(Text(AppLocalization.format("%d° at highest", degrees)))
    }
}

/// Low-poly glass renders of each station (see Documentation/DesignReview/ObservationHome/stations.py).
struct ObservationStationIcon: View {
    @Environment(\.colorScheme) private var colorScheme
    let pass: Pass
    var body: some View {
        Image(ObservationOpportunity.category(pass) == .iss ? "station_iss" : "station_tiangong", bundle: .module)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .saturation(colorScheme == .dark ? 0.08 : 1)
            .colorMultiply(colorScheme == .dark ? AppTheme.text : .white)
            .shadow(color: AppTheme.accent.opacity(0.45), radius: 8)
            .accessibilityHidden(true)
    }
}

/// Passes grouped under one day heading inside a card, separated by single hairlines.
struct ObservationPassGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.weight(.semibold))
                .padding(.horizontal, 4)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) { content }
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
        }
    }
}

struct ObservationRowDivider: View {
    var body: some View {
        Rectangle().fill(AppTheme.border.opacity(0.7)).frame(height: 0.5).padding(.leading, 82)
    }
}
