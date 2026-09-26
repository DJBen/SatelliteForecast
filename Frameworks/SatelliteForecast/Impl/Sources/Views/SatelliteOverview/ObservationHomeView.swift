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
    @State private var preview: ObservationPreview?
    @State private var previewKey: PreviewKey?
    @State private var previewFailed = false
    @State private var previewAttempt = 0
    @State private var isVisible = false
    @State private var skyIsVisible = true
    @State private var reminderTask: Task<Void, Never>?
    /// Set when the user closes the Remind me row; the bell shortcut then lives on the card corner.
    @AppStorage("homeReminderDismissed") private var reminderDismissed = false
    @Namespace private var reminderNamespace

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
            .navigationDestination(for: ForecastRoute.self) { route in
                switch route {
                case .allPasses: allPasses
                case .pass(let pass): DeepLinkContent(session: session, link: pass.link)
                }
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
                            isActive: isVisible && skyIsVisible && !showsLocation && session.navigation.forecastPath.isEmpty && session.navigation.deepLink == nil)
                            .frame(height: dynamicType.isAccessibilitySize ? 180 : 194)
                            .onScrollVisibilityChange(threshold: 0.1) { skyIsVisible = $0 }
                    } else if previewFailed {
                        Label(AppLocalization.text("Pass preview unavailable"), systemImage: "cloud")
                            .font(.subheadline).foregroundStyle(AppTheme.muted)
                            .frame(maxWidth: .infinity, minHeight: 190)
                    } else {
                        ProgressView().frame(maxWidth: .infinity, minHeight: 194)
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
        .overlay(alignment: .topTrailing) {
            if showsBellShortcut(pass) { bellShortcut.padding(14) }
        }
    }

    /// Reminder presentation depends on the OS permission state:
    /// authorized → nothing; denied → bell that opens Settings; never asked → the Remind me row,
    /// or the bell once the row was closed.
    private func showsReminderRow(_ pass: Pass) -> Bool {
        !session.notifications.isAuthorized && !session.notifications.isDenied && !reminderDismissed
    }
    private func showsBellShortcut(_ pass: Pass) -> Bool {
        guard !session.notifications.isAuthorized else { return false }
        return session.notifications.isDenied || reminderDismissed
    }

    private var bellShortcut: some View {
        Button {
            if session.notifications.isDenied { openNotificationSettings() } else { enableReminders() }
        } label: {
            Image(systemName: "bell")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 36, height: 36)
                .background(AppTheme.accent.opacity(0.14), in: Circle())
                .matchedGeometryEffect(id: "reminderBell", in: reminderNamespace)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(session.notifications.isDenied ? "Open notification settings" : "Remind me", bundle: .module))
    }

    private func openNotificationSettings() {
        guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    /// Enables ISS and Tiangong push reminders through the notification permission prompt.
    /// No local notification is scheduled; the backend delivers reminders to authorized devices.
    /// The row is hidden once permission is granted or denied, and can be closed with the
    /// secondary button, which moves the bell to the card corner.
    @ViewBuilder
    private func reminderButton(_ pass: Pass) -> some View {
        let requesting = session.notifications.isRequestingAuthorization
        let tooLate = ObservationOpportunity.start(pass) - 300.0 / 86400 <= now
        if tooLate {
            primaryButton(title: "Start observing", icon: "location.north.line", requesting: false) { open(pass) }
        } else if showsReminderRow(pass) {
            HStack(spacing: 10) {
                Button {
                    withAnimation(.spring(duration: 0.45, bounce: 0.2)) { reminderDismissed = true }
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.muted)
                        .frame(width: 52)
                        .frame(maxHeight: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(AppTheme.muted)
                .buttonBorderShape(.roundedRectangle(radius: 16))
                .accessibilityLabel(Text("Hide reminder button", bundle: .module))
                primaryButton(title: requesting ? "Turning on reminders…" : "Remind me", icon: "bell", requesting: requesting,
                    matched: true) { enableReminders() }
                    .disabled(requesting)
                    .accessibilityHint(Text("Allows notifications for ISS and Tiangong passes", bundle: .module))
            }
            .fixedSize(horizontal: false, vertical: true)
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
        }
    }

    private func primaryButton(title: String, icon: String, requesting: Bool, matched: Bool = false,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if requesting { ProgressView().tint(Color(uiColor: .systemBackground)) }
                else if matched {
                    Image(systemName: icon).matchedGeometryEffect(id: "reminderBell", in: reminderNamespace)
                } else { Image(systemName: icon) }
                Text(AppLocalization.text(title)).fixedSize(horizontal: false, vertical: true)
            }
            .font(.title3.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 32)
            .padding(.vertical, 10)
        }
        .buttonStyle(.borderedProminent)
        .tint(AppTheme.accent)
        .foregroundStyle(Color(uiColor: .systemBackground))
        .buttonBorderShape(.roundedRectangle(radius: 16))
    }

    private var upcoming: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Coming up", bundle: .module).font(.title3.weight(.semibold))
                Spacer()
                Button { session.navigation.forecastPath.append(ForecastRoute.allPasses) } label: {
                    HStack(spacing: 4) {
                        Text("All passes", bundle: .module)
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                    }.font(.subheadline).foregroundStyle(AppTheme.accent)
                }.frame(minHeight: 44)
            }
            .padding(.horizontal, 4)
            let next = Array(passes.dropFirst().prefix(3))
            if next.isEmpty {
                Text("No more visible station passes in this forecast.", bundle: .module)
                    .font(.subheadline).foregroundStyle(AppTheme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 4).padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(next.enumerated()), id: \.element.notificationIdentifier) { offset, pass in
                        if offset > 0 { ObservationRowDivider() }
                        ObservationPassRow(pass: pass, now: now) { open(pass) }
                    }
                }
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
            }
        }
    }

    /// Every visible pass in the forecast, grouped by day.
    private var allPasses: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ForEach(passGroups, id: \.title) { group in
                    ObservationPassGroup(title: group.title) {
                        ForEach(Array(group.passes.enumerated()), id: \.element.notificationIdentifier) { offset, pass in
                            if offset > 0 { ObservationRowDivider() }
                            ObservationPassRow(pass: pass, now: now, showsDay: false) { open(pass) }
                        }
                    }
                }
                if passes.isEmpty {
                    Text("No visible station passes in the next 7 days", bundle: .module)
                        .font(.subheadline).foregroundStyle(AppTheme.muted).padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .modifier(AppSurface())
        .navigationTitle(Text("All passes", bundle: .module))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private var passGroups: [(title: String, passes: [Pass])] {
        var groups: [(title: String, passes: [Pass])] = []
        for pass in passes {
            let title = ObservationPassRow.dayLabel(date(pass), now: now, locale: locale, timeZone: timeZone)
            if let index = groups.firstIndex(where: { $0.title == title }) { groups[index].passes.append(pass) }
            else { groups.append((title, [pass])) }
        }
        return groups
    }

    private var locationPrompt: some View {
        VStack(alignment: .leading, spacing: 18) {
            ObservationExamplePreview(session: session, isActive: isVisible && !showsLocation)
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
        ObservationPassRow.dayLabel(date(pass), now: now, locale: locale, timeZone: timeZone)
    }
    private func summary(_ pass: Pass) -> String {
        AppLocalization.format("%@ · %d° at highest", PassPreviewCell.visibleDurationText(for: pass, locale: locale),
            Int((pass.highestIlluminated?.elev ?? pass.culmination.elev).rounded()))
    }
    /// Pushes the timed pass screen onto the forecast stack; notifications keep the sheet route.
    private func open(_ pass: Pass) {
        guard let observer = input.observer else { showsLocation = true; return }
        session.navigation.forecastPath.append(ForecastRoute.pass(.init(category: ObservationOpportunity.category(pass),
            noradIndex: pass.noradIndex, observer: observer, passTime: Date(julianDate: pass.culmination.julianDate))))
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
    private func enableReminders() {
        reminderTask?.cancel()
        reminderTask = Task { @MainActor in _ = await session.enableStationReminders() }
    }
}
