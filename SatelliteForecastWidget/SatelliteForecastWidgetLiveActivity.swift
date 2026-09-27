import ActivityKit
import WidgetKit
import SwiftUI
import SatelliteWidgetSupport

struct SatelliteForecastWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StationPassActivity.self) { context in
            StationPassActivityView(pass: context.attributes, state: context.state, stale: context.isStale)
                .activityBackgroundTint(MoonstonePalette.surface)
                .activitySystemActionForegroundColor(MoonstonePalette.accent)
                .widgetURL(context.attributes.url)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    StationPassActivityView(pass: context.attributes, state: context.state, stale: context.isStale)
                }
            } compactLeading: {
                ActivityStationIcon(station: context.attributes.station).frame(width: 26, height: 24)
            } compactTrailing: {
                if context.isStale { Image(systemName: "clock").foregroundStyle(MoonstonePalette.accent) }
                else { StationPassCountdown(pass: context.attributes, state: context.state).font(.caption.monospacedDigit()).frame(width: 46) }
            } minimal: {
                ActivityStationIcon(station: context.attributes.station).frame(width: 24, height: 24)
            }
            .widgetURL(context.attributes.url)
            .keylineTint(MoonstonePalette.accent)
        }
    }
}

private struct ActivityStationIcon: View {
    @Environment(\.locale) private var locale
    let station: Int
    var body: some View {
        StationPassIcon(station: station)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(WidgetStrings.text(station == 25544 ? "iss.full" : "tiangong.full", locale: locale))
    }
}
