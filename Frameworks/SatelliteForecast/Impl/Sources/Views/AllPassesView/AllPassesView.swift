//
//  AllPassesView.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 6/14/21.
//

import BTree
import CoreLocation
import CombineRex
import CombineRextensions
import SatelliteForecast
import SatelliteKit
import SwiftUI

public enum AllPassesViewAction {
    /// Calculate the passes.
    case calculatePasses(CalculatePassesParams)
    /// Recaculate passes using the latest location.
    case recalculatePasses(CalculatePassesParams)
    case scheduleNotification(PassNotification, passSnapshots: PassSnapshots)
    case unscheduleNotification(pass: Pass)
}

public struct AllPassesViewContext {
    public let satelliteInfo: SatelliteInfo
    public let julianDateRange: ClosedRange<Double>
    public let observer: LatLonAlt?
    public let julianDateProvider: () -> Double

    public init(
        satelliteInfo: SatelliteInfo,
        julianDateRange: ClosedRange<Double>,
        observer: LatLonAlt?,
        julianDateProvider: @escaping () -> Double
    ) {
        self.satelliteInfo = satelliteInfo
        self.julianDateRange = julianDateRange
        self.observer = observer
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
    public var satelliteCategory: SatelliteCategory?
    public var satelliteTrails: [UInt: SatelliteTrails] = [:]

    public init(
        julianDateOffset: Double = 0,
        scheduledPassNotifications: Set<ScheduledPassNotification> = [],
        skyChartResources: SkyChartResources = .init(),
        backgroundSkyResources: BackgroundSkyResources = .init(),
        location: CLLocation? = nil,
        placemark: CLPlacemark? = nil,
        selectedPassIndex: Int? = nil,
        showsPassAlarmSettingsModal: Bool = false,
        satelliteCategory: SatelliteCategory? = nil,
        satelliteTrails: [UInt : SatelliteTrails] = [:]
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

    let refreshTimer = Timer.publish(
        every: 5,
        on: .main,
        in: .common
    )
    .autoconnect()
    .map(\.julianDate)

    let coordinateRefreshTimer = Timer.publish(
        every: 5,
        on: .main,
        in: .common
    )
    .autoconnect()
    .map(\.julianDate)

    struct MissionControlState: Equatable, Hashable {
        var dateCoordinate: DateCoordinate
        var groundTrack: [DateCoordinate]
    }

    @State var missionControlState: MissionControlState?
    @State var missionControlStateForCoordinate: MissionControlState?

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
                            satelliteName: context.satelliteInfo.elements.commonName,
                            category: viewModel.state.satelliteCategory,
                            observer: context.observer!,
                            timing: .rise,
                            timeOffset: 0
                        ),
                        passSnapshots: item.passSnapshots
                    )
                )
                
            } label: {
                Label("Alarm", systemImage: "bell.fill")
            }
            .tint(.orange)
        }
    }

    @ViewBuilder private func passesList(_ items: [Item]?, observer: LatLonAlt) -> some View {
        if let items = items {
            if items.isEmpty {
                Text("No passes found")
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
                            snapshots: item.passSnapshots.snapshots,
                            notableSnapshots: item.passSnapshots.notableSnapshots,
                            observer: observer,
                            pass: item.passSnapshots.pass,
                            hasScheduledAlert: item.hasScheduledAlert,
                            skyChartProducer: skyChartProducer,
                            julianDateOffset: viewModel.state.julianDateOffset,
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
            ProgressView("Calculating...")
        }
    }

    private var visiblePassHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(AllPassesView.Section.VisiblePasses.header)
                .font(.headline.lowercaseSmallCaps())
                .foregroundColor(Color(UIColor.label))
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
            if let missionControlState = missionControlState {
                MissionControlView(
                    currentDateCoordinate: missionControlState.dateCoordinate,
                    satelliteGroundTrack: missionControlState.groundTrack
                )
                .aspectRatio(1.33, contentMode: .fill)
                .padding([.leading, .trailing], -16)
            } else {
                Color.clear
            }

            if let missionControlState = missionControlStateForCoordinate {
                Text(
                    CLLocationCoordinate2D(missionControlState.dateCoordinate.coordinate).formattedString
                )
                .textCase(nil)
                .font(.caption)
                .foregroundColor(.secondary)

                Text(
                    Self.MissionControlHeader.altitudeString(
                        missionControlState.dateCoordinate.coordinate.alt
                    )
                )
                .textCase(nil)
                .font(.caption)
                .foregroundColor(.secondary)
            }
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
                                    observer: LatLonAlt(lat: locationChangeWarning.observer.latitude, lon: locationChangeWarning.observer.longitude, alt: 0)
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
                        MotionManagerView(
                            isActive: Binding<Bool>(
                                get: {
                                    // Disables the motion when modal is up, because it seems to interfere with picker view
                                    !viewModel.state.showsPassAlarmSettingsModal
                                },
                                set: { _ in }
                            )
                        ) { deviceMotionResult in
                            passViewProducer.view(
                                PassViewContext(
                                    passIndex: allPassViewNavigation.passIndex,
                                    satelliteInfo: context.satelliteInfo,
                                    category: viewModel.state.satelliteCategory,
                                    julianDateRange: context.julianDateRange,
                                    observer: observer,
                                    passSnapshots: allPassViewNavigation.passSnapshots,
                                    julianDateProvider: context.julianDateProvider,
                                    deviceMotion: deviceMotionResult
                                )
                            )
                        }
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "questionmark.circle")
                        .font(.title)
                    Text(
                        """
                        We need a location to find satellite passes. You may set one up within location settings.
                        """
                    )
                    .foregroundColor(Color(UIColor.secondaryLabel))
                    .multilineTextAlignment(.center)
                    .padding(EdgeInsets(top: 0, leading: 32, bottom: 0, trailing: 32))
                }
            }
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
                    Text(context.satelliteInfo.elements.commonName)
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
        .onReceive(refreshTimer) { timerJulianDate in
            missionControlState = missionControlState(julianDate: timerJulianDate + viewModel.state.julianDateOffset)
        }
        .onReceive(coordinateRefreshTimer) { timerJulianDate in
            missionControlStateForCoordinate = missionControlState(julianDate: timerJulianDate + viewModel.state.julianDateOffset)
        }
        .onLoad {
            missionControlState = missionControlState(julianDate: context.julianDateProvider() + viewModel.state.julianDateOffset)
        }
    }

    private func missionControlState(julianDate: Double) -> MissionControlState? {
        let jd = julianDate + viewModel.state.julianDateOffset
        do {
            let satelliteCoordinate = try Satellite(
                withTLE: context.satelliteInfo.elements
            ).geoPosition(
                julianDays: jd
            )
            let groundTrack = try context.satelliteInfo.elements.generateGroundTrack(
                julianDateRange: (jd - TimeConstants.hrs2day)...(jd + TimeConstants.hrs2day),
                interval: TimeConstants.min2day
            )
            return MissionControlState(
                dateCoordinate: DateCoordinate(julianDate: jd, coordinate: satelliteCoordinate),
                groundTrack: groundTrack
            )
        } catch {
            print("Error generating ground track: \(error)")
            return nil
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
                    "AllPassesView.section.visible.headerCaption",
                    tableName: nil,
                    bundle: .module,
                    value: """
                    Satellites can be seen when the sky is dark enough while still being \
                    illuminated by the sun. Viewing condition is best short after sunset and \
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
                    "AllPassesView.section.invisible.headerCaption",
                    tableName: nil,
                    bundle: .module,
                    value: """
                    Satellites faded into earth's shadow cannot be seen; \
                    like stars, they cannot be seen in broad daylight either.
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

        let observer = LatLonAlt(lat: -27.1570, lon: -109.4274, alt: 0)
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
        let observer = LatLonAlt(lat: -27.1570, lon: -109.4274, alt: 0)
        let location = CLLocation(observer)
        let context = AllPassesViewContext(
            satelliteInfo: SatelliteInfo(elements: tianHe),
            julianDateRange: Date().julianDate...Date().julianDate + 1,
            observer: observer,
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
                            satelliteCategory: nil,
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
                                satelliteInfo: SatelliteInfo(elements: tianHe),
                                snapshots: passSnapshots.snapshots,
                                observer: observer,
                                pass: passSnapshots.pass,
                                notableSnapshots: NotableSnapshots(
                                    rise: passSnapshots.notableSnapshots.rise,
                                    transit: passSnapshots.notableSnapshots.transit,
                                    set: passSnapshots.notableSnapshots.set,
                                    illuminationChanges: passSnapshots.notableSnapshots.illuminationChanges
                                ),
                                configs: SkyChartConfigs(
                                    backgroundSkyConfigs: BackgroundSkyConfigs(
                                        stars: .limitedMagnitude(2),
                                        showConstellationLines: false,
                                        visibleBodies: [.sun, .moon],
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
