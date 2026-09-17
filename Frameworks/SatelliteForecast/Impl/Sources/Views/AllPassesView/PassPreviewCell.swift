import SwiftUI
import SatelliteForecast
@preconcurrency import SatelliteKit
import StarryNight

struct PassPreviewCell: View {
    var satelliteInfo: SatelliteInfo
    var observer: LatLonAlt
    var passSnapshots: PassSnapshots
    var hasScheduledAlert: Bool
    var skyChartFactory: ViewFactory<SkyChartContext<EmptyView, EmptyView>, SkyChart<EmptyView, EmptyView>>
    var julianDateOffset: Double
    var starManager: AppStarCatalog
    var julianDateProvider: () -> Double

    @Environment(\.compactHeightLayout) private var compactHeight
    @Environment(\.locale) private var locale

    private var pass: Pass { passSnapshots.pass }
    private var bestDate: Date { Date(julianDate: Self.bestViewTime(for: pass)) }

    private var chart: some View {
        skyChartFactory.view(
            SkyChartContext(satelliteInfo: satelliteInfo, observer: observer,
                passSnapshots: passSnapshots, configs: .preview, quality: .onboarding,
                starManager: starManager, julianDateProvider: julianDateProvider)
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    var body: some View {
        if pass.visibility == .visible {
            GeometryReader { geometry in
                HStack(spacing: 16) {
                    let chartSize = min(190, geometry.size.width * 0.47) * 1.1
                    chart
                        .frame(width: chartSize, height: chartSize)
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Text(bestDate, format: .dateTime.month(.abbreviated).day().year())
                                .font(.headline)
                                .fixedSize(horizontal: false, vertical: true)
                            if hasScheduledAlert {
                                Image(systemName: "bell.fill")
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.accent)
                                    .accessibilityLabel(Text("Alarm scheduled", bundle: .module))
                            }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(bestDate, format: .dateTime.hour().minute())
                                .font(.system(.title2, design: .rounded, weight: .semibold))
                                .foregroundStyle(AppTheme.accent)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Text(Self.visibleDurationText(for: pass, locale: locale))
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        Text(Self.relativeDate(pass: pass, referenceDate: julianDateProvider() + julianDateOffset))
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.muted)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .padding(.vertical, compactHeight ? 8 : 12)
                }
                .frame(maxHeight: .infinity)
            }
            .foregroundStyle(.primary)
            .accessibilityElement(children: .combine)
        } else {
            VStack(spacing: 8) {
                chart.aspectRatio(1, contentMode: .fit)
                VStack(spacing: 3) {
                    Text(bestDate, format: .dateTime.month(.abbreviated).day().year())
                        .font(.subheadline.weight(.medium))
                    Text(bestDate, format: .dateTime.hour().minute())
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.muted)
                }
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                    .strokeBorder(AppTheme.border, lineWidth: 0.5)
            }
            .foregroundStyle(.primary)
            .accessibilityElement(children: .combine)
        }
    }

    static func bestViewTime(for pass: Pass) -> Double {
        (pass.visibility == .visible ? pass.highestIlluminated : nil)?.julianDate ?? pass.culmination.julianDate
    }

    /// Sunlit time above the horizon. Preserve each illumination segment rather
    /// than counting shadow gaps between the first and last visible moments.
    static func visibleDurationSeconds(for pass: Pass) -> Double {
        guard pass.visibility == .visible else { return 0 }
        var start = pass.rise.julianDate
        var illuminated = pass.illumination.initiallyIlluminated
        var duration = 0.0
        for change in pass.illumination.changes {
            let end = min(pass.set.julianDate, max(start, change.datePosition.julianDate))
            if illuminated { duration += end - start }
            start = end
            switch change {
            case .entersShadow: illuminated = false
            case .exitsShadow: illuminated = true
            }
        }
        if illuminated { duration += max(0, pass.set.julianDate - start) }
        return duration * TimeConstants.day2sec
    }

    static func visibleDurationText(for pass: Pass, locale: Locale) -> String {
        let seconds = visibleDurationSeconds(for: pass)
        if seconds < 60 {
            return NSLocalizedString("Visible for less than 1 min", bundle: .module, comment: "A short visible satellite pass")
        }
        let minutes = max(1, Int((seconds / 60).rounded()))
        return String(format: NSLocalizedString("Visible for %@ min", bundle: .module,
            comment: "%@ is the approximate visible duration in minutes, formatted for the locale"),
            minutes.formatted(.number.locale(locale)))
    }
}

extension PassPreviewCell {
    static func titleForPassVisibility(_ visibility: Pass.Visibility) -> String {
        switch visibility {
        case .visible:
            return NSLocalizedString(
                "PassPreviewCell.visibilityText.visible",
                tableName: nil,
                bundle: .module,
                value: "Visible",
                comment: "The pass is visible"
            )
        case .daylight:
            return NSLocalizedString(
                "PassPreviewCell.visibilityText.daylight",
                tableName: nil,
                bundle: .module,
                value: "Daylight",
                comment: "The pass happens during daylight"
            )
        case .unlit:
            return NSLocalizedString(
                "PassPreviewCell.visibilityText.unlit",
                tableName: nil,
                bundle: .module,
                value: "Unlit",
                comment: "The pass happens entirely unlit"
            )
        }
    }

    private static let durationFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        formatter.formattingContext = .beginningOfSentence
        return formatter
    }()

    static func relativeDate(pass: Pass, referenceDate: Double) -> String {
        if referenceDate < pass.rise.julianDate {
            let format = NSLocalizedString(
                "PassPreviewCell.relativeDate.riseInTheFuture",
                tableName: nil,
                bundle: .module,
                value: "%@",
                comment: "A string describing that the satellite rises in a specific time in the future"
            )
            return String(
                format: format,
                durationFormatter.localizedString(
                    fromTimeInterval: (pass.rise.julianDate - referenceDate) * TimeConstants.day2sec)
            )
        } else if referenceDate > pass.set.julianDate {
            let format = NSLocalizedString(
                "PassPreviewCell.relativeDate.alreadyPassed",
                tableName: nil,
                bundle: .module,
                value: "%@",
                comment: "A string describing that the satellite has already set in a specific time in the past"
            )
            return String(
                format: format,
                durationFormatter.localizedString(
                    fromTimeInterval: (pass.set.julianDate - referenceDate) * TimeConstants.day2sec)
            )
        } else {
            return NSLocalizedString(
                "PassPreviewCell.relativeDate.passing",
                tableName: nil,
                bundle: .module,
                value: "Passing now",
                comment: "A string describing that the satellite is currently passing"
            )
        }
    }

}
