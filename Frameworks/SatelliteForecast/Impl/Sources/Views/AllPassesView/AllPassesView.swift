//
//  AllPassesView.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 6/14/21.
//

import BTree
import CoreLocation
@preconcurrency import CombineRex
@preconcurrency import CombineRextensions
import SatelliteForecast
@preconcurrency import SatelliteKit
import StarryNight
import SwiftUI

public struct AllPassesViewContext {
    public let satelliteInfo: SatelliteInfo
    public let julianDateRange: ClosedRange<Double>
    public let observer: LatLonAlt?
    public let starManager: any StarManaging
    public let julianDateProvider: () -> Double

    public init(
        satelliteInfo: SatelliteInfo,
        julianDateRange: ClosedRange<Double>,
        observer: LatLonAlt?,
        starManager: any StarManaging,
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

struct AllPassViewNavigation {
    let passIndex: Int
    let passSnapshots: PassSnapshots
}

extension AllPassViewNavigation: Equatable, Hashable, Codable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(passIndex)
    }
}

public struct AllPassesView: View {
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

    @ObservedObject var viewModel: ObservableViewModel<AllPassesViewAction, AllPassesViewState>

    let context: AllPassesViewContext
    let skyChartProducer: ViewProducer<SkyChartContext<EmptyView, EmptyView>, SkyChart<EmptyView, EmptyView>>
    let passViewProducer: ViewProducer<PassViewContext, PassView>

    public init(
        viewModel: ObservableViewModel<AllPassesViewAction, AllPassesViewState>,
        context: AllPassesViewContext,
        skyChartProducer: ViewProducer<SkyChartContext<EmptyView, EmptyView>, SkyChart<EmptyView, EmptyView>>,
        passViewProducer: ViewProducer<PassViewContext, PassView>
    ) {
        self.viewModel = viewModel
        self.context = context
        self.skyChartProducer = skyChartProducer
        self.passViewProducer = passViewProducer
    }

    private var itemsByVisibility: [Pass.Visibility: [Item]]? {
        guard let satelliteTrail = viewModel.state.satelliteTrails[context.satelliteInfo.noradIndex],
              let passSnapshotsList = satelliteTrail.passSnapshots else {
            return nil
        }

        let items = passSnapshotsList.enumerated().map { index, passSnapshots -> Item in
            let rasterizedSatellitePath = viewModel.state.skyChartResources.previewSatellitePaths[passSnapshots.pass]
            let rasterizedBackgroundSky: UIImage?
            if let observer = context.observer {
                rasterizedBackgroundSky = viewModel.state.backgroundSkyResources.previewBackgroundSkies[
                    BackgroundSkyKey(
                        observer: observer,
                        configs: .preset
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
                viewModel.dispatch(
                    .unscheduleNotification(pass: item.passSnapshots.pass)
                )
            } label: {
                Label("Cancel alarm", systemImage: "bell.slash.fill")
            }
            .tint(.red)
        } else {
            Button {
                viewModel.dispatch(
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
            } else {
                ForEach(items) { item in
                    NavigationLink(
                        value: AllPassViewNavigation(
                            passIndex: item.index,
                            passSnapshots: item.passSnapshots
                        )
                    ) {
                        PassPreviewCell(
                            satelliteInfo: context.satelliteInfo,
                            observer: observer,
                            passSnapshots: item.passSnapshots,
                            hasScheduledAlert: item.hasScheduledAlert,
                            skyChartProducer: skyChartProducer,
                            julianDateOffset: viewModel.state.julianDateOffset,
                            starManager: context.starManager,
                            julianDateProvider: context.julianDateProvider
                        )
                    }
                    .frame(height: 135)
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
        }
    }

    private var visiblePassHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(AllPassesView.Section.VisiblePasses.header)
                    .font(.headline.lowercaseSmallCaps())
                    .foregroundColor(Color(UIColor.label))

                Spacer()
                
                Button {
                    viewModel.dispatch(.showOnboarding(true))
                } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.subheadline)
                        .foregroundColor(Color(UIColor.secondaryLabel))
                }
                .accessibilityLabel(Text("Show help", bundle: .module, comment: "Accessibility label for help button"))
            }
            Text(AllPassesView.Section.VisiblePasses.headerCaption)
                .font(.caption)
                .foregroundColor(Color(UIColor.secondaryLabel))
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
                .foregroundColor(Color(UIColor.secondaryLabel))
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
        VStack(spacing: 0) {
            if let locationChangeWarning = locationChangeWarning {
                AllPassesLocationChangeWarning(
                    state: locationChangeWarning,
                    onRecalculatePasses: {
                        viewModel.dispatch(
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

            if let observer = context.observer {
                let items = itemsByVisibility
                let visiblePasses: [Item] = items?[.visible] ?? []
                let invisiblePasses: [Item] = (items?[.daylight] ?? []) + (items?[.unlit] ?? [])

                SwiftUI.List {
                    SwiftUI.Section(header: mapHeader()) {
                        EmptyView()
                    }

                    SwiftUI.Section(header: visiblePassHeader) {
                        passesList(visiblePasses, observer: observer)
                    }

                    SwiftUI.Section(header: invisiblePassHeader) {
                        passesList(invisiblePasses, observer: observer)
                    }
                }
                .navigationDestination(for: AllPassViewNavigation.self) { allPassViewNavigation in
                    LazyView {
                        passViewProducer.view(
                            PassViewContext(
                                passIndex: allPassViewNavigation.passIndex,
                                satelliteInfo: context.satelliteInfo,
                                satelliteCommonName: satelliteCommonName,
                                category: viewModel.state.satelliteCategory,
                                julianDateRange: context.julianDateRange,
                                observer: observer,
                                passSnapshots: allPassViewNavigation.passSnapshots,
                                starManager: context.starManager,
                                julianDateProvider: context.julianDateProvider,
                            )
                        )
                    }
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
                        .foregroundColor(Color(UIColor.secondaryLabel))
                        .font(.footnote)
                        .multilineTextAlignment(.leading)
                        .padding(EdgeInsets(top: 0, leading: 32, bottom: 0, trailing: 32))
                    }
                    
                    VStack(spacing: 16) {
                        Button {
                            viewModel.dispatch(.deeplinkToLocationSelection)
                        } label: {
                            Text("\(Image(systemName: "dot.circle.and.hand.point.up.left.fill").symbolRenderingMode(.hierarchical)) Manually select a location", bundle: .module)
                        }
                        .buttonStyle(.bordered)
                        
                        Button {
                            viewModel.dispatch(.showLocationSettings)
                        } label: {
                            Text("\(Image(systemName: "gear").symbolRenderingMode(.hierarchical)) Allow location access", bundle: .module)
                        }
                        .buttonStyle(.bordered)
                    }
                }
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
        .frame(maxWidth: .infinity)
        .navigationTitle(context.satelliteInfo.elements.commonName)
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
        .onAppear {
            // Check if this is the first time viewing AllPassesView
            if !UserDefaults.standard.bool(forKey: "hasCompletedAllPassesOnboarding") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    // Double-check the UserDefaults in case the user completed onboarding during the delay
                    if !UserDefaults.standard.bool(forKey: "hasCompletedAllPassesOnboarding") {
                        viewModel.dispatch(.showOnboarding(true))
                    }
                }
            }
        }
        .fullScreenCover(isPresented: Binding<Bool>(
            get: { viewModel.state.showsOnboarding },
            set: { isPresented in
                // If the sheet is being dismissed (isPresented = false) and we haven't completed onboarding yet,
                // mark it as completed since the user has seen it
                if !isPresented && viewModel.state.showsOnboarding && !UserDefaults.standard.bool(forKey: "hasCompletedAllPassesOnboarding") {
                    viewModel.dispatch(.completeOnboarding)
                }
                viewModel.dispatch(.showOnboarding(isPresented))
            }
        )) {
            AllPassesOnboardingView(
                onComplete: {
                    viewModel.dispatch(.completeOnboarding)
                },
                skyChartProducer: skyChartProducer
            )
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

#if DEBUG

struct AllPassesView_Previews: PreviewProvider {
    static let tianHe: Elements = try! Elements(
        raw: """
            TIANHE
            1 48274U 21035A   21152.91865056  .00003057  00000-0  33542-4 0  9993
            2 48274  41.4713  16.3199 0005053  25.9394 109.3813 15.65195495  5304
            """
    )

    static let tianHePasses: [PassSnapshots] = {
        let elements = tianHe

        let formatter = ISO8601DateFormatter()
        let date = formatter.date(from: "2021-06-02T06:29:00-0600")!

        let observer = LatLonAlt(-27.1570, -109.4274, 0)
        let snapshots = try! SatelliteInfo(elements: elements).generateSnapshots(
            observer: observer,
            julianDateRange: date.julianDate...date.julianDate + 2
        )

        return try! SatelliteInfo(elements: elements).findPasses(
            observer: observer,
            coarseSnapshots: snapshots
        )
    }()

    static var previews: some View {
        let observer = LatLonAlt(-27.1570, -109.4274, 0)
        let location = CLLocation(observer)
        let context = AllPassesViewContext(
            satelliteInfo: try! SatelliteInfo(elements: tianHe),
            julianDateRange: Date().julianDate...Date().julianDate + 1,
            observer: observer,
            starManager: StarManagerMock(),
            julianDateProvider: { Date().julianDate }
        )
        let passSnapshots = tianHePasses[0]

        ForEach(["iPhone SE (2nd generation)", "iPhone 13 Pro Max"], id: \.self) { previewDevice in
            NavigationStack {
                AllPassesView(
                    viewModel: .mock(
                        state: AllPassesViewState(
                            scheduledPassNotifications: [],
                            skyChartResources: .init(),
                            backgroundSkyResources: .init(),
                            location: location,
                            placemark: nil,
                            selectedPassIndex: nil,
                            satelliteCategory: .tianhe,
                            satelliteTrails: [48274: SatelliteTrails(observer: observer, passSnapshots: tianHePasses)]
                        )
                    ),
                    context: context,
                    skyChartProducer: ViewProducer<SkyChartContext<EmptyView, EmptyView>, SkyChart<EmptyView, EmptyView>> { context in
                        return SkyChart(
                            viewModel: .mock(
                                state: SkyChartViewState()
                            ),
                            context: SkyChartContext<EmptyView, EmptyView>(
                                satelliteInfo: try! SatelliteInfo(elements: tianHe),
                                observer: observer,
                                passSnapshots: passSnapshots,
                                configs: SkyChartConfigs(
                                    backgroundSkyConfigs: BackgroundSkyConfigs(
                                        stars: .brightest300,
                                        showConstellationLines: false,
                                        visibleBodies: [.sun, .moon, .venus, .jupiter],
                                        bodySymbol: .symbol
                                    ),
                                    basicChartConfigs: BasicChartConfigs(
                                        showAzimuthTexts: false,
                                        azimuthMarkInterval: 90,
                                        azimuthMarkLength: 2,
                                        showDirections: false
                                    ),
                                    showPassInfoLabels: false
                                ),
                                quality: .preview,
                                starManager: StarManagerMock(),
                                julianDateProvider: { passSnapshots.pass.rise.julianDate }
                            ),
                            backgroundSkyViewProducer: .pure(
                                BackgroundSkyView(
                                    viewModel: .mock(
                                        state: BackgroundSkyViewState()
                                    ),
                                    context: BackgroundSkyViewContext(
                                        observer: observer,
                                        basicChartConfigs: .init(),
                                        configs: .preset,
                                        quality: .full,
                                        starManager: StarManagerMock(),
                                        constellationLabel: { _ in EmptyView() },
                                        annotationView: { _ in EmptyView() },
                                        starTapped: { _ in }
                                    )
                                )
                            )
                        )
                    },
                    passViewProducer: .crash
                )
            }
            .previewDevice(PreviewDevice(rawValue: previewDevice))
            .environment(\.backgroundSkyJulianDateKey, passSnapshots.pass.rise.julianDate.roundJulianDate(.toMins(1)))
        }
    }
}

#endif
