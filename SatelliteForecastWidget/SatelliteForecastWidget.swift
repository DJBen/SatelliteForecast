import AppIntents
import SwiftUI
import WidgetKit
import SatelliteWidgetSupport

enum SmallWidgetLayout: String, AppEnum {
    case stations, chart
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Small widget style"
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .stations: "Both stations", .chart: "Pass chart"
    ]
}

enum WidgetStation: String, AppEnum {
    case iss, tiangong
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Station"
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [.iss: "ISS", .tiangong: "Tiangong"]
    var norad: Int { self == .iss ? 25544 : 48274 }
}

struct StationWidgetConfiguration: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Next passes"
    static let description = IntentDescription("Choose a small-widget style and its chart station. Medium shows both stations. Large shows the next visible pass across both stations.")
    @Parameter(title: "Small widget style", default: .stations) var layout: SmallWidgetLayout
    @Parameter(title: "Small chart station", default: .iss) var station: WidgetStation
}

struct StationEntry: TimelineEntry {
    let date: Date
    let forecast: WidgetForecast?
    let configuration: StationWidgetConfiguration
}

struct StationProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> StationEntry {
        let now = Date()
        return .init(date: now, forecast: .preview(at: now), configuration: .init())
    }
    func snapshot(for configuration: StationWidgetConfiguration, in context: Context) async -> StationEntry {
        let now = Date()
        return .init(date: now, forecast: context.isPreview ? .preview(at: now) : WidgetForecastStore.read(), configuration: configuration)
    }
    func timeline(for configuration: StationWidgetConfiguration, in context: Context) async -> Timeline<StationEntry> {
        let now = Date()
        let forecast = WidgetForecastStore.read()
        // Hourly reloads extend the timeline; cap it so a 7-day forecast stays small to archive.
        let horizon = now.addingTimeInterval(3 * 86_400)
        let dates = forecast?.entryDates(after: now).filter { $0 <= horizon } ?? [now]
        // Keep each serialized entry small: only the next pass for each station is displayed.
        let entries = dates.map { date in
            let compact = forecast.map { saved in
                WidgetForecast(generated: saved.generated, expires: saved.expires,
                    passes: [saved.next(station: 25544, at: date), saved.next(station: 48274, at: date)].compactMap { $0 })
            }
            return StationEntry(date: date, forecast: compact, configuration: configuration)
        }
        return Timeline(entries: entries, policy: .after(now.addingTimeInterval(3600)))
    }
}

struct StationWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StationEntry
    var body: some View {
        StationWidgetView(forecast: entry.forecast, date: entry.date, family: family,
                          chart: entry.configuration.layout == .chart, station: entry.configuration.station.norad)
            .padding(StationWidgetView.contentPadding(for: family))
            .containerBackground(for: .widget) { StationWidgetView.background }
    }
}

struct SatelliteForecastWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: WidgetForecastStore.kind, intent: StationWidgetConfiguration.self, provider: StationProvider()) {
            StationWidgetEntryView(entry: $0)
        }
        .configurationDisplayName("Space Station Passes")
        .description("The next visible ISS and Tiangong passes for your app location. Choose two station rows or a simple chart in the small size.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        // The 16 pt system inset leaves the medium rows floating; use our own tighter margins.
        .contentMarginsDisabled()
    }
}

#Preview("Both stations", as: .systemSmall) {
    SatelliteForecastWidget()
} timeline: {
    let now = Date()
    StationEntry(date: now, forecast: .preview(at: now), configuration: .init())
}
