import SwiftUI
import CoreLocation
import SatelliteForecast
import SatelliteKit

struct ObservationHomeView: View {
    let session: AppSession
    let model: ForecastModel
    let context: SatelliteOverviewViewContext
    @Environment(\.locale) private var locale
    @Environment(\.timeZone) private var timeZone
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicType
    @State private var showsLocation = false
    @State private var showsAll = false
    @State private var preview: ObservationPreview?
    @State private var previewKey: PreviewKey?
    @State private var previewFailed = false
    @State private var previewAttempt = 0
    @State private var isVisible = false
    @State private var skyIsVisible = true
    @State private var isScheduling = false
    @State private var reminderTask: Task<Void, Never>?

    init(session: AppSession, model: ForecastModel, context: SatelliteOverviewViewContext,
         initialPreview: ObservationPreview? = nil) {
        self.session = session
        self.model = model
        self.context = context
        _preview = State(initialValue: initialPreview)
        _previewKey = State(initialValue: initialPreview.map {
            PreviewKey(pass: $0.snapshots.pass, observer: session.location.resources.location.map(LatLonAlt.init), attempt: 0)
        })
    }

    private struct PreviewKey: Equatable {
        let pass: Pass?
        let observer: LatLonAlt?
        let attempt: Int
    }
    private var input: ForecastInput {
        .init(observer: session.location.resources.location.map(LatLonAlt.init),
            julianDateOffset: session.debug.config.effectiveOffset,
            authorizationStatus: session.location.resources.authorizationStatus)
    }
    private var now: Double { model.currentDate.julianDate + input.julianDateOffset }
    private var passes: [Pass] { model.upcomingPasses }
    private var request: PreviewKey { .init(pass: passes.first, observer: input.observer, attempt: previewAttempt) }
    private var currentPreview: ObservationPreview? { previewKey == request ? preview : nil }
    private var isLoading: Bool {
        if case .loading = model.issNextPass { return true }
        if case .loading = model.tianheNextPass { return true }
        return false
    }
    private var hasFailure: Bool {
        if case .failed = model.issNextPass { return true }
        if case .failed = model.tianheNextPass { return true }
        return false
    }
    private var locationName: String {
        let resources = session.location.resources
        if let locality = resources.placemark?.locality { return locality }
        if case let .custom(completion, _) = resources.selection { return completion.title }
        return AppLocalization.text(resources.location == nil ? "Choose a location" : "Current location")
    }

    var body: some View {
        @Bindable var navigation = session.navigation
        NavigationStack(path: $navigation.forecastPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    if input.observer == nil {
                        locationPrompt
                    } else if let pass = passes.first {
                        hero(pass)
                        upcoming
                        if hasFailure { failureNotice }
                    } else if isLoading {
                        ProgressView(AppLocalization.text("Finding your next observation…"))
                            .frame(maxWidth: .infinity, minHeight: 240)
                    } else {
                        emptyState
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .modifier(AppSurface())
            .toolbar(.hidden, for: .navigationBar)
            .refreshable {
                AppAnalytics.event("refresh_requested", screen: .forecast)
                await model.refresh(input)
            }
            .analyticsScreen(.forecast)
            .navigationDestination(isPresented: $showsAll) { allPasses }
            .navigationDestination(for: SpecialSatellite.self) { station in
                ScreenFactory(session: session).detail(.init(selectedNoradIndex: station.rawValue,
                    julianDateRange: JulianDateUtil.createJulianDateRange(now: now), observer: input.observer,
                    starManager: session.catalog, julianDateProvider: context.julianDateProvider))
            }
            .sheet(isPresented: $showsLocation) {
                NavigationStack {
                    LocationSettingsView(state: .init(locationSelection: session.location.resources.selection,
                        currentLocation: session.location.resources.currentLocation,
                        currentLocationPlacemark: session.location.resources.currentLocationPlacemark),
                        selectLocation: { session.location.select($0) },
                        requestCurrentLocation: { session.location.useCurrentLocation() })
                    .toolbar { ToolbarItem(placement: .confirmationAction) {
                        Button(AppLocalization.text("Done")) { showsLocation = false }
                    } }
                }
            }
            .onAppear { isVisible = true }
            .onDisappear { isVisible = false; reminderTask?.cancel() }
            .task(id: input) {
                guard !SnapshotEnvironment.isEnabled else { return }
                await model.run(input)
            }
            .task(id: request) { await loadPreview(request) }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Next observation", bundle: .module).font(.largeTitle.bold())
                .accessibilityAddTraits(.isHeader)
            Button { showsLocation = true } label: {
                HStack(spacing: 7) {
                    Image(systemName: "mappin.and.ellipse").foregroundStyle(AppTheme.muted)
                    Text(locationName).foregroundStyle(.primary).lineLimit(2)
                    Text("Change", bundle: .module).foregroundStyle(AppTheme.accent).font(.subheadline)
                }
                .font(.subheadline)
                .frame(minHeight: 40, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
    }

    private func hero(_ pass: Pass) -> some View {
        VStack(spacing: 0) {
            Button { open(pass) } label: {
                VStack(alignment: .leading, spacing: 9) {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .firstTextBaseline, spacing: 9) {
                            Text(dayLabel(pass))
                            Text(date(pass), format: .dateTime.hour().minute())
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(dayLabel(pass))
                            Text(date(pass), format: .dateTime.hour().minute())
                        }
                    }
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    Text(ObservationOpportunity.name(pass)).font(.headline).foregroundStyle(.primary)
                    Text(summary(pass)).font(.subheadline).foregroundStyle(AppTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    if let preview = currentPreview, let observer = input.observer {
                        ObservationSkyPreview(preview: preview, observer: observer, session: session,
                            isActive: isVisible && skyIsVisible && !showsLocation && !showsAll && session.navigation.deepLink == nil)
                            .frame(height: dynamicType.isAccessibilitySize ? 240 : 258)
                            .onScrollVisibilityChange(threshold: 0.1) { skyIsVisible = $0 }
                    } else if previewFailed {
                        Label(AppLocalization.text("Pass preview unavailable"), systemImage: "cloud")
                            .font(.subheadline).foregroundStyle(AppTheme.muted)
                            .frame(maxWidth: .infinity, minHeight: 190)
                    } else {
                        ProgressView().frame(maxWidth: .infinity, minHeight: 258)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("Opens the sky chart for this pass", bundle: .module))
            if previewFailed {
                Button(AppLocalization.text("Retry preview")) { previewAttempt += 1 }
                    .padding(.bottom, 10)
            }
            reminderButton(pass)
                .padding(.top, 4)
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LinearGradient(colors: [AppTheme.surface, AppTheme.background], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
    }

    private func reminderButton(_ pass: Pass) -> some View {
        let scheduled = session.notifications.scheduled.contains { $0.id == pass.notificationIdentifier }
        let tooLate = ObservationOpportunity.start(pass) - 300.0 / 86400 <= now
        return Button {
            if scheduled { session.notifications.cancel([pass.notificationIdentifier]) }
            else if tooLate { open(pass) }
            else { schedule(pass) }
        } label: {
            HStack(spacing: 8) {
                if isScheduling { ProgressView().tint(.black) }
                else { Image(systemName: scheduled ? "bell.badge.fill" : tooLate ? "location.north.line" : "bell") }
                Text(AppLocalization.text(isScheduling ? "Setting reminder…" : scheduled ? "Reminder set" : tooLate ? "Start observing" : "Remind me 5 min before"))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 28)
            .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(AppTheme.accent)
        .foregroundStyle(Color(uiColor: .systemBackground))
        .buttonBorderShape(.roundedRectangle(radius: 16))
        .disabled(isScheduling || (!tooLate && !scheduled && currentPreview == nil))
        .accessibilityHint(Text(scheduled ? "Tap to cancel this reminder" : "", bundle: .module))
    }

    private var upcoming: some View {
        VStack(spacing: 2) {
            HStack {
                Text("Coming up", bundle: .module).font(.title3.weight(.semibold))
                Spacer()
                Button { showsAll = true } label: {
                    HStack(spacing: 4) {
                        Text("All passes", bundle: .module)
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                    }.font(.subheadline).foregroundStyle(AppTheme.accent)
                }.frame(minHeight: 44)
            }
            ForEach(Array(passes.dropFirst().prefix(3)), id: \.notificationIdentifier) { pass in row(pass) }
            if passes.count == 1 {
                Text("No more visible station passes in this forecast.", bundle: .module)
                    .font(.subheadline).foregroundStyle(AppTheme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 12)
            }
        }
    }

    private func row(_ pass: Pass) -> some View {
        Button { open(pass) } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(ObservationOpportunity.name(pass)).font(.headline).foregroundStyle(.primary)
                    Text(summary(pass)).font(.caption).foregroundStyle(AppTheme.muted)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 6) {
                    Text(date(pass), format: .dateTime.hour().minute()).font(.headline).foregroundStyle(.primary)
                    Text(dayLabel(pass)).font(.caption).foregroundStyle(AppTheme.muted)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) { Rectangle().fill(AppTheme.border.opacity(0.6)).frame(height: 0.5) }
    }

    private var allPasses: some View {
        List {
            Section { ForEach(passes, id: \.notificationIdentifier) { row($0) } }
            Section {
                NavigationLink(value: SpecialSatellite.iss) { Text(SatelliteOverviewCell.satelliteOfSpecialInterestLocalizedTitle(.iss)) }
                NavigationLink(value: SpecialSatellite.tianhe) { Text(SatelliteOverviewCell.satelliteOfSpecialInterestLocalizedTitle(.tianhe)) }
            } header: { Text("Explore space stations", bundle: .module) }
        }
        .modifier(AppSurface())
        .navigationTitle(Text("All passes", bundle: .module))
        .toolbar(.visible, for: .navigationBar)
    }

    private var locationPrompt: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "sparkles").font(.largeTitle).foregroundStyle(AppTheme.accent)
            Text("See a space station with your own eyes.", bundle: .module).font(.title2.bold())
            Text("Choose where you’ll be watching. We’ll find the next visible pass and show you where to look.", bundle: .module)
                .foregroundStyle(AppTheme.muted)
            Button { session.location.useCurrentLocation() } label: {
                HStack {
                    if session.location.isRequestingLocation { ProgressView() }
                    Label(AppLocalization.text("Use my location"), systemImage: "location.fill")
                }.frame(maxWidth: .infinity, minHeight: 32)
            }
            .buttonStyle(.borderedProminent).tint(AppTheme.accent)
            .foregroundStyle(Color(uiColor: .systemBackground)).font(.headline)
            .disabled(session.location.isRequestingLocation)
            Button(AppLocalization.text("Choose a city")) { showsLocation = true }
                .frame(maxWidth: .infinity, minHeight: 40)
            if let error = session.location.locationError { Text(error).font(.footnote).foregroundStyle(AppTheme.warning) }
        }
        .padding(24)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 24))
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: hasFailure ? "wifi.exclamationmark" : "moon.stars").font(.largeTitle).foregroundStyle(AppTheme.accent)
            Text(hasFailure ? "Unable to load pass information" : "No visible station passes in the next 7 days", bundle: .module).font(.title2.bold())
            Text(hasFailure ? "Check your connection and try again." : "Try another observing location or explore other satellites.", bundle: .module)
                .foregroundStyle(AppTheme.muted)
            if hasFailure { retryButton }
            else {
                Button(AppLocalization.text("Change location")) { showsLocation = true }
                Button(AppLocalization.text("Explore satellites")) { session.navigation.tab = .satellites }
            }
        }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 24))
    }
    private var failureNotice: some View {
        HStack {
            Text("Some station passes could not be loaded.", bundle: .module).font(.footnote).foregroundStyle(AppTheme.muted)
            Spacer()
            retryButton
        }
    }
    private var retryButton: some View {
        Button(AppLocalization.text("Retry")) { Task { await model.refresh(input) } }
    }
    private func date(_ pass: Pass) -> Date { Date(julianDate: ObservationOpportunity.start(pass)) }
    private func dayLabel(_ pass: Pass) -> String {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = timeZone
        let current = Date(julianDate: now), target = date(pass)
        if calendar.isDate(target, inSameDayAs: current) {
            return AppLocalization.text(calendar.component(.hour, from: target) >= 18 ? "Tonight" : "Today")
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: current), calendar.isDate(target, inSameDayAs: tomorrow) {
            return AppLocalization.text("Tomorrow")
        }
        return target.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, locale: locale, timeZone: timeZone))
    }
    private func summary(_ pass: Pass) -> String {
        AppLocalization.format("%@ · %d° at highest", PassPreviewCell.visibleDurationText(for: pass, locale: locale),
            Int((pass.highestIlluminated?.elev ?? pass.culmination.elev).rounded()))
    }
    private func open(_ pass: Pass) {
        guard let observer = input.observer else { showsLocation = true; return }
        session.open(ObservationOpportunity.category(pass), id: pass.noradIndex, observer: observer,
            passTime: Date(julianDate: pass.culmination.julianDate), fromNotification: false)
    }
    private func loadPreview(_ key: PreviewKey) async {
        guard !SnapshotEnvironment.isEnabled, previewKey != key else { return }
        preview = nil; previewFailed = false; previewKey = key
        guard let pass = key.pass, let observer = key.observer else { return }
        do {
            guard let info = try await model.satelliteInfo(for: pass.noradIndex == 25544 ? .iss : .tianhe) else {
                throw ForecastServiceError.missingSatellite(pass.noradIndex)
            }
            let trails = try await session.orbits.trails(info: info, observer: observer,
                range: (pass.rise.julianDate - 5.0 / 1440)...(pass.set.julianDate + 5.0 / 1440))
            try Task.checkCancellation()
            guard previewKey == key else { return }
            guard let found = DeepLinkPassResolver.select(trails.passSnapshots ?? [], at: pass.culmination.julianDate) else {
                throw ForecastServiceError.missingSatellite(pass.noradIndex)
            }
            preview = .init(info: info, snapshots: .init(pass: pass, snapshots: found.snapshots, notableSnapshots: found.notableSnapshots))
        } catch is CancellationError { if previewKey == key { previewKey = nil } }
        catch { if !Task.isCancelled && previewKey == key { previewFailed = true } }
    }
    private func schedule(_ pass: Pass) {
        guard !isScheduling, let preview = currentPreview, let observer = input.observer else { return }
        isScheduling = true
        reminderTask = Task { @MainActor in
            defer { isScheduling = false }
            await session.notifications.schedule(ObservationOpportunity.reminder(pass, observer: observer),
                snapshots: preview.snapshots, catalog: session.catalog, offset: input.julianDateOffset,
                rapid: session.debug.config.rapidNotificationDelivery, fromForecast: true)
        }
    }
}
