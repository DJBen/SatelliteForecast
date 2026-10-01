import SwiftUI

struct HomeWeatherBadge: View {
    let reading: HomeWeatherReading
    let action: () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        Button(action: action) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    iconAndTemperature
                    Text(AppLocalization.text(reading.condition.title)).foregroundStyle(AppTheme.muted)
                }
                .fixedSize(horizontal: true, vertical: false)
                iconAndTemperature
            }
            .font(.subheadline)
            .foregroundStyle(AppTheme.text)
            .frame(minHeight: 40, alignment: .trailing)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(AppLocalization.text(reading.condition.title)), \(reading.temperature(locale: locale))"))
        .accessibilityHint(Text("Show weather details", bundle: .module))
        .accessibilityIdentifier("home.weather")
    }

    private var iconAndTemperature: some View {
        HStack(spacing: 6) {
            Image(systemName: reading.condition.symbol).symbolRenderingMode(.multicolor)
            Text(reading.temperature(locale: locale)).monospacedDigit().fontWeight(.medium)
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

struct HomeWeatherAttribution: View {
    let reading: HomeWeatherReading
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Link(destination: reading.legalURL) {
            HStack(spacing: 5) {
                AsyncImage(url: reading.logoURL(dark: colorScheme == .dark)) { image in
                    image.resizable().scaledToFit().frame(width: 86, height: 12)
                } placeholder: {
                    Text(verbatim: " Weather").font(.caption2)
                }
                Image(systemName: "arrow.up.right").font(.system(size: 8))
            }
            .foregroundStyle(AppTheme.muted)
        }
        .accessibilityLabel(Text("Apple Weather data sources", bundle: .module))
    }
}

struct HomeWeatherDetails: View {
    let reading: HomeWeatherReading
    let locationName: String
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: reading.condition.symbol)
                    .symbolRenderingMode(.multicolor).font(.system(size: 48))
                Text(reading.temperature(locale: locale)).font(.largeTitle.weight(.semibold))
                Text(AppLocalization.text(reading.condition.title)).font(.title3)
                Text("Hourly forecast", bundle: .module).font(.subheadline).foregroundStyle(AppTheme.muted)
                Text(reading.forecastTime, format: .dateTime.hour().minute())
                    .font(.subheadline).foregroundStyle(AppTheme.muted)
                HomeWeatherAttribution(reading: reading)
                Link(destination: reading.legalURL) {
                    Text("Apple Weather data sources", bundle: .module).font(.footnote)
                }
            }
            .padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.background).foregroundStyle(AppTheme.text)
            .navigationTitle(locationName).toolbarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button(AppLocalization.text("Done")) { dismiss() }
            } }
        }
        .tint(AppTheme.accent)
        .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
    }
}
