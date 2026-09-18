//
//  AllPassesView.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 6/14/21.
//

import BTree
import CoreLocation
import SatelliteForecast
@preconcurrency import SatelliteKit
import StarryNight
import SwiftUI

public struct AllPassesViewContext {
    public let satelliteInfo: SatelliteInfo
    public let julianDateRange: ClosedRange<Double>
    public let observer: LatLonAlt?
    public let starManager: AppStarCatalog
    public let julianDateProvider: () -> Double

    public init(
        satelliteInfo: SatelliteInfo,
        julianDateRange: ClosedRange<Double>,
        observer: LatLonAlt?,
        starManager: AppStarCatalog,
        julianDateProvider: @escaping () -> Double
    ) {
        self.satelliteInfo = satelliteInfo
        self.julianDateRange = julianDateRange
        self.observer = observer
        self.starManager = starManager
        self.julianDateProvider = julianDateProvider
    }
}

public struct AllPassesViewState {
    public var julianDateOffset: Double = 0
    public var scheduledPassNotifications: Set<ScheduledPassNotification> = []
    public var skyChartResources: SkyChartResources = .init()
    public var backgroundSkyResources: BackgroundSkyResources = .init()
    public var location: CLLocation?
    public var placemark: CLPlacemark?
    public var selectedPassIndex: Int?
    public var showsPassAlarmSettingsModal: Bool
    public var satelliteCategory: SatelliteCategory
    public var satelliteTrails: [UInt: SatelliteTrails] = [:]
    public var showsOnboarding: Bool = false

    public init(
        julianDateOffset: Double = 0,
        scheduledPassNotifications: Set<ScheduledPassNotification> = [],
        skyChartResources: SkyChartResources = .init(),
        backgroundSkyResources: BackgroundSkyResources = .init(),
        location: CLLocation? = nil,
        placemark: CLPlacemark? = nil,
        selectedPassIndex: Int? = nil,
        showsPassAlarmSettingsModal: Bool = false,
        satelliteCategory: SatelliteCategory = .iss,
        satelliteTrails: [UInt : SatelliteTrails] = [:],
        showsOnboarding: Bool = false
    ) {
        self.julianDateOffset = julianDateOffset
        self.scheduledPassNotifications = scheduledPassNotifications
        self.skyChartResources = skyChartResources
        self.backgroundSkyResources = backgroundSkyResources
        self.location = location
        self.placemark = placemark
        self.selectedPassIndex = selectedPassIndex
        self.showsPassAlarmSettingsModal = showsPassAlarmSettingsModal
        self.satelliteCategory = satelliteCategory
        self.satelliteTrails = satelliteTrails
        self.showsOnboarding = showsOnboarding
    }
}

extension AllPassesViewState: Equatable {}

struct AllPassViewNavigation: Identifiable {
    var id: Int { passIndex }
    let passIndex: Int
    let passSnapshots: PassSnapshots
}

extension AllPassViewNavigation: Equatable, Hashable, Codable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(passIndex)
    }
}

public struct AllPassesView: View {
    @AppStorage("hasCompletedAllPassesOnboarding") private var hasOpenedVisiblePass = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.passNavigationPath) private var navigationPath
    struct Item: Equatable, Identifiable {
        let index: Int
        let passSnapshots: PassSnapshots
        let hasScheduledAlert: Bool

        private let rasterizedSatellitePath: UIImage?
        private let rasterizedBackgroundSky: UIImage?

        init(
            index: Int,
            passSnapshots: PassSnapshots,
            hasScheduledAlert: Bool,
            rasterizedSatellitePath: UIImage? = nil,
            rasterizedBackgroundSky: UIImage? = nil
        ) {
            self.index = index
            self.passSnapshots = passSnapshots
            self.hasScheduledAlert = hasScheduledAlert
            self.rasterizedSatellitePath = rasterizedSatellitePath
            self.rasterizedBackgroundSky = rasterizedBackgroundSky
        }

        var id: String {
            return "\(passSnapshots.pass.notificationIdentifier)-scheduled:\(hasScheduledAlert)"
        }
    }

    @State var viewModel: PassListModel

    let context: AllPassesViewContext
    let skyChartFactory: ViewFactory<SkyChartContext<EmptyView, EmptyView>, SkyChart<EmptyView, EmptyView>>
    let passViewFactory: ViewFactory<PassViewContext, PassView>

    public init(
        viewModel: PassListModel,
        context: AllPassesViewContext,
        skyChartFactory: ViewFactory<SkyChartContext<EmptyView, EmptyView>, SkyChart<EmptyView, EmptyView>>,
        passViewFactory: ViewFactory<PassViewContext, PassView>
    ) {
        self.viewModel = viewModel
        self.context = context
        self.skyChartFactory = skyChartFactory
        self.passViewFactory = passViewFactory
    }

    private var itemsByVisibility: [Pass.Visibility: [Item]]? {
        guard let satelliteTrail = viewModel.state.satelliteTrails[context.satelliteInfo.noradIndex],
              let passSnapshotsList = satelliteTrail.passSnapshots else {
            return nil
        }

        let items = passSnapshotsList.enumerated().map { index, passSnapshots -> Item in
            let rasterizedSatellitePath = viewModel.state.skyChartResources.previewSatellitePaths[SkyPathKey(pass: passSnapshots.pass, isDark: colorScheme == .dark)]
            let rasterizedBackgroundSky: UIImage?
            if let observer = context.observer {
                rasterizedBackgroundSky = viewModel.state.backgroundSkyResources.previewBackgroundSkies[
                    BackgroundSkyKey(
                        observer: observer,
                        configs: .preset,
                        isDark: colorScheme == .dark
                    )
                ]?[passSnapshots.pass.rise.julianDate.roundJulianDate(.toMins(1))]
            } else {
                rasterizedBackgroundSky = nil
            }
            return Item(
                index: index,
                passSnapshots: passSnapshots,
                hasScheduledAlert: viewModel.state.scheduledPassNotifications.contains(
                    where: { $0.id == passSnapshots.pass.notificationIdentifier }
                ),
                rasterizedSatellitePath: rasterizedSatellitePath,
                rasterizedBackgroundSky: rasterizedBackgroundSky
            )
        }
        return Dictionary(grouping: items, by: \.passSnapshots.pass.visibility)
    }

    private var locationChangeWarning: AllPassesLocationChangeWarningState? {
        guard let observer = context.observer.map({ CLLocation($0).coordinate }),
              let newObserver = viewModel.state.location?.coordinate else {
            return nil
        }
        if CLLocation(latitude: observer.latitude, longitude: observer.longitude).distance(from: CLLocation(latitude: newObserver.latitude, longitude: newObserver.longitude)) > 1000 {
            return AllPassesLocationChangeWarningState(
                observer: newObserver,
                observerDescription: viewModel.state.placemark?.formattedString,
                oldObserver: observer
            )
        } else {
            return nil
        }
    }
    
    @ViewBuilder private func swipeActionLeftButtons(item: Item) -> some View {
        if item.hasScheduledAlert {
            Button {
                viewModel.send(
                    .unscheduleNotification(pass: item.passSnapshots.pass)
                )
            } label: {
                Label("Cancel alarm", systemImage: "bell.slash.fill")
            }
            .tint(.red)
        } else {
            Button {
                viewModel.send(
                    .scheduleNotification(
                        PassNotification(
                            pass: item.passSnapshots.pass,
                            satelliteName: satelliteCommonName,
                            category: viewModel.state.satelliteCategory,
                            observer: context.observer!,
                            timing: .rise,
                            timeOffset: 0
                        ),
                        passSnapshots: item.passSnapshots
                    )
                )
                
            } label: {
                Label {
                    Text("Alarm", bundle: .module, comment: "The verb as in alarm clock 'alarms' somebody")
                } icon: {
                    Image(systemName: "bell.fill")
                }
            }
            .tint(.orange)
        }
    }

    @ViewBuilder private func passesList(_ items: [Item]?, observer: LatLonAlt) -> some View {
        if let items = items {
            if items.isEmpty {
                Text(
                    "No passes found",
                    bundle: .module,
                    comment: "The default text when no satellite passes are found"
                )
                .listRowBackground(AppTheme.surface)
            } else {
                ForEach(items) { item in
                    NavigationLink(
                        value: AllPassViewNavigation(
                            passIndex: item.index,
                            passSnapshots: item.passSnapshots
                        )
                    ) {
                        previewCell(item, observer: observer)
                    }
                    .modifier(VisiblePassRowHeight())
                    .overlay {
                        if !hasOpenedVisiblePass, item.index == items.first?.index,
                           item.passSnapshots.pass.visibility == .visible {
                            DiscoveryGlow()
                                .padding(.horizontal, -14)
                                .padding(.vertical, -12)
                        }
                    }
                    .listRowBackground(AppTheme.surface)
                    .id(item.id)
                    .swipeActions(
                        edge: .leading
                    ) {
                        swipeActionLeftButtons(item: item)
                    }
                }
            }
        } else {
            ProgressView {
                Text(
                    "Calculating...",
                    bundle: .module,
                    comment: "The progress text when calculating satellite passes"
                )
            }
            .listRowBackground(AppTheme.surface)
        }
    }

    private func previewCell(_ item: Item, observer: LatLonAlt) -> some View {
        PassPreviewCell(satelliteInfo: context.satelliteInfo, observer: observer,
            passSnapshots: item.passSnapshots, hasScheduledAlert: item.hasScheduledAlert,
            skyChartFactory: skyChartFactory, julianDateOffset: viewModel.state.julianDateOffset,
            starManager: context.starManager, julianDateProvider: context.julianDateProvider)
    }

    @ViewBuilder private func invisiblePassGrid(_ items: [Item]?, observer: LatLonAlt) -> some View {
        if let items, !items.isEmpty {
            // Each pair is its own List row, keeping the long forecast lazily rendered.
            ForEach(Array(stride(from: 0, to: items.count, by: 2)), id: \.self) { start in
                HStack(alignment: .top, spacing: 12) {
                    ForEach(Array(items[start..<min(start + 2, items.count)])) { item in
                        // Both cards append to the owning stack, like visible-pass links.
                        // Separate Buttons also prevent List from activating both links in a row.
                        Button {
                            guard let navigationPath else {
                                assertionFailure("Pass grid requires its owning navigation path")
                                return
                            }
                            navigationPath.wrappedValue.append(AllPassViewNavigation(
                                passIndex: item.index, passSnapshots: item.passSnapshots))
                        } label: {
                            previewCell(item, observer: observer)
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                    }
                    if start + 1 == items.count {
                        Color.clear.frame(maxWidth: .infinity).accessibilityHidden(true)
                    }
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        } else {
            passesList(items, observer: observer)
        }
    }

    private func passDestination(_ navigation: AllPassViewNavigation, observer: LatLonAlt) -> some View {
        LazyView {
            passViewFactory.view(
                PassViewContext(passIndex: navigation.passIndex, satelliteInfo: context.satelliteInfo,
                    satelliteCommonName: satelliteCommonName, category: viewModel.state.satelliteCategory,
                    julianDateRange: context.julianDateRange, observer: observer,
                    passSnapshots: navigation.passSnapshots, starManager: context.starManager,
                    julianDateProvider: context.julianDateProvider)
            )
        }
        .modifier(FirstVisiblePassTutorial(isVisible: navigation.passSnapshots.pass.visibility == .visible))
    }

    private var visiblePassHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(AllPassesView.Section.VisiblePasses.header)
                    .font(.headline.lowercaseSmallCaps())
                    .foregroundColor(Color(UIColor.label))

                Spacer()
                
                Button {
                    viewModel.send(.showOnboarding(true))
                } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.muted)
                }
                .accessibilityLabel(Text("Show help", bundle: .module, comment: "Accessibility label for help button"))
            }
            Text(AllPassesView.Section.VisiblePasses.headerCaption)
                .font(.caption)
                .foregroundColor(AppTheme.muted)
        }
        .textCase(nil)
    }

    private var invisiblePassHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(AllPassesView.Section.InvisiblePasses.header)
                .font(.headline.lowercaseSmallCaps())
                .foregroundColor(Color(UIColor.label))
            Text(AllPassesView.Section.InvisiblePasses.headerCaption)
                .font(.caption)
                .foregroundColor(AppTheme.muted)
        }
        .textCase(nil)
    }
    
    @ViewBuilder private func mapHeader() -> some View {
        VStack {
            MissionControlView(
                satelliteInfo: context.satelliteInfo,
                julianDateProvider: context.julianDateProvider,
                julianDateOffset: viewModel.state.julianDateOffset,
                userLocation: viewModel.state.location
            )
            .aspectRatio(1.33, contentMode: .fill)
            .padding([.leading, .trailing], -16)
        }
    }

    @ViewBuilder private var allPassesList: some View {
        Group {
            if let observer = context.observer {
                let items = itemsByVisibility
                let visiblePasses: [Item]? = items.map { $0[.visible] ?? [] }
                let invisiblePasses: [Item]? = items.map {
                    (($0[.daylight] ?? []) + ($0[.unlit] ?? [])).sorted {
                        $0.passSnapshots.pass.rise.julianDate < $1.passSnapshots.pass.rise.julianDate
                    }
                }

                SwiftUI.List {
                    SwiftUI.Section(header: mapHeader()) {
                        EmptyView()
                    }

                    SwiftUI.Section(header: visiblePassHeader) {
                        passesList(visiblePasses, observer: observer)
                    }

                    SwiftUI.Section(header: invisiblePassHeader) {
                        invisiblePassGrid(invisiblePasses, observer: observer)
                    }
                }
                .navigationDestination(for: AllPassViewNavigation.self) { navigation in
                    passDestination(navigation, observer: observer)
                }
            } else {
                VStack(spacing: 32) {
                    VStack(spacing: 16) {
                        Image(systemName: "location.slash")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.red, Color(uiColor: .label))
                            .font(.title)
                        
                        Text(
                        """
                        Need a location to find satellite passes.
                        """
                        )
                        .foregroundColor(Color(UIColor.label))
                        .multilineTextAlignment(.leading)
                        .padding(EdgeInsets(top: 0, leading: 32, bottom: 0, trailing: 32))
                        
                        Text(
                            """
                            Did you know? Space stations orbits earth 15 times a day, and maybe up to 5-7 times above your location, but most of the time it's either too bright or too dark to be seen.
                            """
                        )
                        .foregroundColor(AppTheme.muted)
                        .font(.footnote)
                        .multilineTextAlignment(.leading)
                        .padding(EdgeInsets(top: 0, leading: 32, bottom: 0, trailing: 32))
                    }
                    
                    VStack(spacing: 16) {
                        Button {
                            viewModel.send(.deeplinkToLocationSelection)
                        } label: {
                            Text("\(Image(systemName: "dot.circle.and.hand.point.up.left.fill").symbolRenderingMode(.hierarchical)) Manually select a location", bundle: .module)
                        }
                        .buttonStyle(.bordered)
                        
                        Button {
                            viewModel.send(.showLocationSettings)
                        } label: {
                            Text("\(Image(systemName: "gear").symbolRenderingMode(.hierarchical)) Allow location access", bundle: .module)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if let locationChangeWarning = locationChangeWarning {
                AllPassesLocationChangeWarning(
                    state: locationChangeWarning,
                    onRecalculatePasses: {
                        viewModel.send(
                            .recalculatePasses(
                                .init(
                                    selectedNoradIndex: context.satelliteInfo.noradIndex,
                                    satelliteInfo: context.satelliteInfo,
                                    julianDateRange: context.julianDateRange,
                                    observer: LatLonAlt(locationChangeWarning.observer.latitude, locationChangeWarning.observer.longitude, 0)
                                )
                            )
                        )
                    }
                )
            }
        }
    }
    
    private var satelliteCommonName: String {
        if context.satelliteInfo.noradIndex == 25544 {
            return NSLocalizedString("International space station", bundle: .module, comment: "The name of ISS")
        } else if context.satelliteInfo.noradIndex == 48274 {
            return NSLocalizedString("Tiangong space station", bundle: .module, comment: "The name of Tiangong space station")
        } else {
            return context.satelliteInfo.elements.commonName
        }
    }
    
    public var body: some View {
        allPassesList
        .modifier(CompactHeightLayout())
        .frame(maxWidth: .infinity)
        .modifier(AppSurface())
        .navigationTitle(context.satelliteInfo.elements.commonName)
        .analyticsScreen(.passes)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(alignment: .center, spacing: 4) {
                    Text(satelliteCommonName)
                        .font(.headline)
                        .frame(alignment: .center)
                        .multilineTextAlignment(.center)
                    
                    Text(
                        AllPassesView.searchPassRangeToolbarText(
                            range: context.julianDateRange,
                            now: context.julianDateProvider() + viewModel.state.julianDateOffset
                        )
                    )
                    .lineLimit(2)
                    .font(.caption)
                    .frame(alignment: .center)
                    .multilineTextAlignment(.center)
                }
            }
        }
        .task(id: context.observer) {
            guard !SnapshotEnvironment.isEnabled else { return }
            if let observer = context.observer {
                viewModel.send(.calculatePasses(.init(selectedNoradIndex: context.satelliteInfo.noradIndex, satelliteInfo: context.satelliteInfo, julianDateRange: context.julianDateRange, observer: observer)))
            }
        }
        .onDisappear { viewModel.cancel() }
        .overlay(alignment: .center) {
            if let error = viewModel.errorMessage {
                ContentUnavailableView { Label("Unable to calculate passes", systemImage: "exclamationmark.triangle") } description: { Text(error) }
            }
        }
        .fullScreenCover(isPresented: Binding<Bool>(
            get: { viewModel.state.showsOnboarding },
            set: { viewModel.send(.showOnboarding($0)) }
        )) {
            PassTutorialVideo {
                viewModel.send(.showOnboarding(false))
            }
        }
    }

}

extension AllPassesView {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static func searchPassRangeToolbarText(range: ClosedRange<Double>, now: Double) -> String {
        let format = NSLocalizedString(
            "AllPassesView.searchPassRangeToolbar.text",
            tableName: nil,
            bundle: .module,
            value: "Showing passes up to %1$@",
            comment: "The auxiliary text under the navigation title detailing the search date range of the passes."
        )

        return String(
            format: format,
            dateFormatter.string(from: Date(julianDate: range.upperBound))
        )
    }

    enum MissionControlHeader {
        static func altitudeString(_ altitude: Double) -> String {
            let altitudeFormat = NSLocalizedString(
                "AllPassesView.missionControlHeader.altitudeFormat",
                tableName: nil,
                bundle: .module,
                value: "%@ km above ground",
                comment: "The altitude format of mission control header"
            )
            let numberFormatter = NumberFormatter()
            numberFormatter.maximumFractionDigits = 2
            numberFormatter.minimumFractionDigits = 2
            return String(format: altitudeFormat, numberFormatter.string(from: altitude as NSNumber)!)
        }
    }

    enum Section {
        enum ObserverInfo {
            static func body(observer: LatLonAlt) -> String {
                let format = NSLocalizedString(
                    "AllPassesView.section.observer.body",
                    tableName: nil,
                    bundle: .module,
                    value: "You are observing from %@.",
                    comment: "The body of observer info"
                )
                return String(
                    format: format,
                    CLLocationCoordinate2D(
                        latitude: observer.lat,
                        longitude: observer.lon
                    ).formattedString
                )
            }
        }

        enum VisiblePasses {
            static var header: String {
                NSLocalizedString(
                    "AllPassesView.section.visible.header",
                    tableName: nil,
                    bundle: .module,
                    value: "Visible Passes",
                    comment: "The header of visible passes"
                )
            }

            static var headerCaption: String {
                NSLocalizedString(
                    "AllPassesView.section.visible.headerCaption.v2",
                    tableName: nil,
                    bundle: .module,
                    value: """
                    Satellites can be seen when the sky is dark while still being \
                    illuminated by the sun. Best viewing condition occurs shortly after sunset and \
                    before sunrise.
                    """,
                    comment: "The caption under the header of visible passes"
                )
            }
        }

        enum InvisiblePasses {
            static var header: String {
                NSLocalizedString(
                    "AllPassesView.section.invisible.header",
                    tableName: nil,
                    bundle: .module,
                    value: "Invisible Passes",
                    comment: "The header of invisible passes"
                )
            }

            static var headerCaption: String {
                NSLocalizedString(
                    "AllPassesView.section.invisible.headerCaption.v2",
                    tableName: nil,
                    bundle: .module,
                    value: """
                    A few reasons can make passes not visible:
                    1. Daylight is too bright;
                    2. Later at night, the satellite fades into earth's shadow.
                    """,
                    comment: "The caption under the header of invisible passes"
                )
            }
        }
    }

}

private struct VisiblePassRowHeight: ViewModifier {
    @Environment(\.compactHeightLayout) private var compactHeight
    @ScaledMetric(relativeTo: .body) private var regularHeight: CGFloat = 202.5
    @ScaledMetric(relativeTo: .body) private var compactRowHeight: CGFloat = 170

    func body(content: Content) -> some View {
        content.frame(height: compactHeight ? compactRowHeight : regularHeight)
    }
}
