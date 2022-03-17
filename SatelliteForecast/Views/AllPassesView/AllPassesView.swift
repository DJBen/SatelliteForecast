//
//  AllPassesView.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/14/21.
//

import BTree
import CoreLocation
import CombineRex
import CombineRextensions
import SatelliteForecastCore
import SatelliteKit
import SwiftUI

enum AllPassesViewAction {
    struct CalculatePassesParams: CustomDebugStringConvertible {
        let selectedNoradIndex: UInt
        let satelliteInfo: SatelliteInfo
        let julianDateRange: ClosedRange<Double>
        let observer: LatLonAlt

        var debugDescription: String {
            return "selectedNoradIndex: \(selectedNoradIndex), julianDateRange: \(julianDateRange), observer: \(observer)"
        }
    }
    
    /// Calculate the passes.
    case calculatePasses(CalculatePassesParams)
    /// Recaculate passes using the latest location.
    case recalculatePasses(CalculatePassesParams)
    case selectPass(index: Int?)
    
    // It will trigger the model change after a delay to accomodate for animation
    case scheduleNotification(PassNotification)
    // It will trigger the model change after a delay to accomodate for animation
    case unscheduleNotification(pass: Pass)
}

struct AllPassesViewContext {
    let selectedNoradIndex: UInt
    let satelliteInfo: SatelliteInfo
    let julianDateRange: ClosedRange<Double>
    let observer: LatLonAlt?
}

struct AllPassesViewState: Equatable {
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

    var julianDate: Double = 0
    var visiblePasses: [Item]?
    var invisiblePasses: [Item]?
    var selectedPassIndex: Int?
    var satelliteCategory: SatelliteCategory?
    var locationChangeWarningState: AllPassesLocationChangeWarningState?

    static func project(state: AppState, context: AllPassesViewContext) -> AllPassesViewState {
        if let satelliteTrails = state.satelliteTrails[context.selectedNoradIndex],
           let passSnapshotsList = satelliteTrails.passSnapshots {
            let items = passSnapshotsList.enumerated().map { index, passSnapshots -> Item in
                let rasterizedSatellitePath = state.skyChartResources.previewSatellitePaths[passSnapshots.pass]
                let rasterizedBackgroundSky: UIImage?
                if let observer = context.observer {
                    rasterizedBackgroundSky = state.backgroundSkyResources.previewBackgroundSkies[
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
                    hasScheduledAlert: state.notificationState.scheduledPassNotifications.contains(
                        where: { $0.id == passSnapshots.pass.notificationIdentifier }
                    ),
                    rasterizedSatellitePath: rasterizedSatellitePath,
                    rasterizedBackgroundSky: rasterizedBackgroundSky
                )
            }
            let itemsByVisibility = Dictionary(grouping: items, by: \.passSnapshots.pass.visibility)
            let visiblePasses = itemsByVisibility[.visible] ?? []
            let invisiblePasses = (itemsByVisibility[.daylight] ?? []) + (itemsByVisibility[.unlit] ?? [])
            let locationStateChangeWarning: AllPassesLocationChangeWarningState? = {
                guard let observer = context.observer.map({ CLLocation($0).coordinate }),
                        let newObserver = state.locationState.location?.coordinate else {
                    return nil
                }
                if CLLocation(latitude: observer.latitude, longitude: observer.longitude).distance(from: CLLocation(latitude: newObserver.latitude, longitude: newObserver.longitude)) > 1000 {
                    return AllPassesLocationChangeWarningState(
                        observer: newObserver,
                        observerDescription: state.locationState.placemark?.formattedString,
                        oldObserver: observer
                    )
                } else {
                    return nil
                }
            }()
            
            return AllPassesViewState(
                julianDate: state.julianDate,
                visiblePasses: visiblePasses
                    .sorted { $0.passSnapshots.pass.rise.julianDate < $1.passSnapshots.pass.rise.julianDate },
                invisiblePasses: invisiblePasses
                    .sorted { $0.passSnapshots.pass.rise.julianDate < $1.passSnapshots.pass.rise.julianDate },
                selectedPassIndex: state.navigationState.listNavigation.selectedPassIndex,
                satelliteCategory: state.navigationState.listNavigation.category,
                locationChangeWarningState: locationStateChangeWarning
            )
        } else {
            return AllPassesViewState(
                julianDate: state.julianDate,
                visiblePasses: nil,
                invisiblePasses: nil,
                selectedPassIndex: state.navigationState.listNavigation.selectedPassIndex,
                satelliteCategory: state.navigationState.listNavigation.category
            )
        }
    }
}

struct AllPassesView: View {
    @ObservedObject var viewModel: ObservableViewModel<AllPassesViewAction, AllPassesViewState>

    let context: AllPassesViewContext
    let skyChartProducer: ViewProducer<SkyChartContext, SkyChart>
    let passViewProducer: ViewProducer<PassViewContext, PassView>

    private func navigationLink<Label: View>(
        item: AllPassesViewState.Item,
        observer: LatLonAlt,
        @ViewBuilder label: () -> Label
    ) -> some View {
        NavigationLink(
            destination: LazyView(
                passViewProducer.view(
                    PassViewContext(
                        satelliteInfo: context.satelliteInfo,
                        julianDateRange: context.julianDateRange,
                        observer: observer,
                        snapshots: item.passSnapshots.snapshots,
                        pass: item.passSnapshots.pass,
                        notableSnapshots: item.passSnapshots.notableSnapshots
                    )
                )
            ),
            tag: item.index,
            selection: Binding<Int?>(
                get: {
                    viewModel.state.selectedPassIndex
                },
                set: {
                    viewModel.dispatch(.selectPass(index: $0))
                }
            ),
            label: label
        )
    }
    
    @ViewBuilder private func swipeActionLeftButtons(item: AllPassesViewState.Item) -> some View {
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
                            timeOffset: 0
                        )
                    )
                )
                
            } label: {
                Label("Alarm", systemImage: "bell.fill")
            }
            .tint(.orange)
        }
    }

    @ViewBuilder private func passesList(_ items: [AllPassesViewState.Item]?, observer: LatLonAlt) -> some View {
        if let items = items {
            if items.isEmpty {
                Text("No passes found")
            } else {
                ForEach(items) { item in
                    navigationLink(item: item, observer: observer) {
                        PassPreviewCell(
                            satelliteInfo: context.satelliteInfo,
                            snapshots: item.passSnapshots.snapshots,
                            notableSnapshots: item.passSnapshots.notableSnapshots,
                            observer: observer,
                            pass: item.passSnapshots.pass,
                            referenceDate: viewModel.state.julianDate,
                            hasScheduledAlert: item.hasScheduledAlert,
                            skyChartProducer: skyChartProducer
                        )
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 10))
                    .frame(height: 135)
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
            Text(LocalizedStrings.AllPassesView.Section.VisiblePasses.header)
                .font(.headline.lowercaseSmallCaps())
                .foregroundColor(Color(UIColor.label))
            Text(LocalizedStrings.AllPassesView.Section.VisiblePasses.headerCaption)
                .font(.caption)
                .foregroundColor(Color(UIColor.secondaryLabel))
        }
        .textCase(nil)
    }

    private var invisiblePassHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(LocalizedStrings.AllPassesView.Section.InvisiblePasses.header)
                .font(.headline.lowercaseSmallCaps())
                .foregroundColor(Color(UIColor.label))
            Text(LocalizedStrings.AllPassesView.Section.InvisiblePasses.headerCaption)
                .font(.caption)
                .foregroundColor(Color(UIColor.secondaryLabel))
        }
        .textCase(nil)
    }
    
    @ViewBuilder private func observerHeader(observer: LatLonAlt) -> some View {
        Text(
            LocalizedStrings.AllPassesView.Section.ObserverInfo.body(observer: observer)
        )
        .font(.headline.lowercaseSmallCaps())
        .foregroundColor(Color(UIColor.secondaryLabel))
        .textCase(nil)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if let locationChangeWarningState = viewModel.state.locationChangeWarningState {
                AllPassesLocationChangeWarning(
                    state: locationChangeWarningState,
                    onRecalculatePasses: {
                        viewModel.dispatch(
                            .recalculatePasses(
                                .init(
                                    selectedNoradIndex: context.selectedNoradIndex,
                                    satelliteInfo: context.satelliteInfo,
                                    julianDateRange: context.julianDateRange,
                                    observer: LatLonAlt(lat: locationChangeWarningState.observer.latitude, lon: locationChangeWarningState.observer.longitude, alt: 0)
                                )
                            )
                        )
                    }
                )
            }
            
            if let observer = context.observer {
                List {
                    Section(header: observerHeader(observer: observer)) {
                        EmptyView()
                    }
                    
                    Section(header: visiblePassHeader) {
                        passesList(viewModel.state.visiblePasses, observer: observer)
                    }

                    Section(header: invisiblePassHeader) {
                        passesList(viewModel.state.invisiblePasses, observer: observer)
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
                        LocalizedStrings.AllPassesView.searchPassRangeToolbarText(
                            range: context.julianDateRange,
                            now: viewModel.state.julianDate
                        )
                    )
                    .lineLimit(2)
                    .font(.caption)
                    .frame(alignment: .center)
                    .multilineTextAlignment(.center)
                }
            }
        }
    }
}

extension ViewProducer where Context == AllPassesViewContext, ProducedView == AllPassesView {
    static func allPassesView<S: StoreType>(viewModel: S) -> ViewProducer where S.ActionType == AppAction, S.StateType == AppState {
        ViewProducer<Context, ProducedView> { context in
            AllPassesView(
                viewModel: viewModel
                    .projection(
                        action: { AppAction.allPassesView($0) },
                        state: { appState in
                            AllPassesViewState.project(
                                state: appState,
                                context: context
                            )
                        }
                    )
                    .asObservableViewModel(initialState: .init(), emitsValue: .whenDifferent),
                context: context,
                skyChartProducer: ViewProducer<SkyChartContext, SkyChart>
                    .skyChart(viewModel: viewModel),
                passViewProducer: ViewProducer<PassViewContext, PassView>
                    .passView(viewModel: viewModel)
            )
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
        let items = tianHePasses.enumerated().map { index, passSnapshots in
            AllPassesViewState.Item(index: index, passSnapshots: passSnapshots, hasScheduledAlert: false)
        }
        let itemsByVisibility = Dictionary(grouping: items, by: \.passSnapshots.pass.visibility)
        let visiblePasses = itemsByVisibility[.visible] ?? []
        let invisiblePasses = (itemsByVisibility[.daylight] ?? []) + (itemsByVisibility[.unlit] ?? [])
        let observer = LatLonAlt(lat: -27.1570, lon: -109.4274, alt: 0)
        let context = AllPassesViewContext(
            selectedNoradIndex: 48274,
            satelliteInfo: SatelliteInfo(elements: tianHe),
            julianDateRange: Date().julianDate...Date().julianDate + 1,
            observer: observer
        )
        let passSnapshots = tianHePasses[0]

        ForEach(["iPhone SE (2nd generation)", "iPhone 13 Pro Max"], id: \.self) { previewDevice in
            NavigationView {
                AllPassesView(
                    viewModel: .mock(
                        state: AllPassesViewState(
                            julianDate: Date().julianDate,
                            visiblePasses: visiblePasses,
                            invisiblePasses: invisiblePasses
                        )
                    ),
                    context: context,
                    skyChartProducer: ViewProducer<SkyChartContext, SkyChart> { context in
                        return SkyChart(
                            viewModel: .mock(
                                state: SkyChartViewState(
                                    referenceDate: passSnapshots.pass.rise.julianDate
                                )
                            ),
                            context: SkyChartContext(
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
                                quality: .preview
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
                                        quality: .full
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
