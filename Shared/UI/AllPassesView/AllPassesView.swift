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
    /// Calculate the passes.
    case calculatePasses(noradIndex: Int, observer: LatLonAlt)
    /// Recaculate passes using the latest location.
    case recalculatePasses(noradIndex: Int)
    case selectPass(index: Int?)
    
    // It will trigger the model change after a delay to accomodate for animation
    case scheduleNotification(PassNotification)
    // It will trigger the model change after a delay to accomodate for animation
    case unscheduleNotification(pass: Pass)
}

struct AllPassesViewState: Equatable {
    struct Item: Equatable, Identifiable {
        let index: Int
        let pass: Pass
        let hasScheduledAlert: Bool
        
        private let rasterizedSatellitePath: UIImage?
        private let rasterizedBackgroundSky: UIImage?

        init(
            index: Int,
            pass: Pass,
            hasScheduledAlert: Bool,
            rasterizedSatellitePath: UIImage? = nil,
            rasterizedBackgroundSky: UIImage? = nil
        ) {
            self.index = index
            self.pass = pass
            self.hasScheduledAlert = hasScheduledAlert
            self.rasterizedSatellitePath = rasterizedSatellitePath
            self.rasterizedBackgroundSky = rasterizedBackgroundSky
        }
        
        var id: String {
            return "\(pass.notificationIdentifier)-scheduled:\(hasScheduledAlert)"
        }
    }

    var satelliteInfo: SatelliteInfo
    var julianDate: Double
    var julianDateRange: Range<Double>
    var observer: LatLonAlt?
    var visiblePasses: [Item]?
    var invisiblePasses: [Item]?
    var selectedPassIndex: Int?
    var satelliteCategory: SatelliteCategory?
    var locationChangeWarningState: AllPassesLocationChangeWarningState?

    static func project(state: AppState) -> AllPassesViewState? {
        guard let selectedNoradIndex = state.navigationState.selectedSatelliteNoradIndex,
            let info = state.satelliteLoaderState[selectedNoradIndex] else {
            return nil
        }

        guard let julianDateRange = state.julianDateRange else {
            return nil
        }

        if let passes = state.satelliteTrails[selectedNoradIndex]?.passes {
            let items = passes.enumerated().map { index, pass -> Item in
                let rasterizedSatellitePath = state.skyChartState.previewSatellitePaths[pass]
                let rasterizedBackgroundSky: UIImage?
                if let observer = state.observer {
                    rasterizedBackgroundSky = state.skyChartState.previewBackgroundSkies[
                        SkyChartBackgroundSkyKey(
                            observer: observer,
                            configs: .preset
                        )
                    ]?.value(closestTo: pass.rise.julianDate)
                } else {
                    rasterizedBackgroundSky = nil
                }
                return Item(
                    index: index,
                    pass: pass,
                    hasScheduledAlert: state.notificationState.scheduledPassNotifications.contains(where: { $0.id == pass.notificationIdentifier }),
                    rasterizedSatellitePath: rasterizedSatellitePath,
                    rasterizedBackgroundSky: rasterizedBackgroundSky
                )
            }
            let itemsByVisibility = Dictionary(grouping: items, by: \.pass.visibility)
            let visiblePasses = itemsByVisibility[.visible] ?? []
            let invisiblePasses = (itemsByVisibility[.daylight] ?? []) + (itemsByVisibility[.unlit] ?? [])
            let locationStateChangeWarning: AllPassesLocationChangeWarningState? = {
                guard let observer = state.observer.map({ CLLocation($0).coordinate }),
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
                satelliteInfo: info,
                julianDate: state.julianDate,
                julianDateRange: julianDateRange,
                observer: state.observer,
                visiblePasses: visiblePasses
                    .sorted { $0.pass.rise.julianDate < $1.pass.rise.julianDate },
                invisiblePasses: invisiblePasses
                    .sorted { $0.pass.rise.julianDate < $1.pass.rise.julianDate },
                selectedPassIndex: state.selectedSatellitePassIndex,
                satelliteCategory: state.navigationState.selectedCategory,
                locationChangeWarningState: locationStateChangeWarning
            )
        } else {
            return AllPassesViewState(
                satelliteInfo: info,
                julianDate: state.julianDate,
                julianDateRange: julianDateRange,
                observer: state.observer,
                visiblePasses: nil,
                invisiblePasses: nil,
                selectedPassIndex: state.selectedSatellitePassIndex,
                satelliteCategory: state.navigationState.selectedCategory
            )
        }
    }
}

struct AllPassesView: View {
    @ObservedObject var viewModel: ObservableViewModel<AllPassesViewAction, AllPassesViewState?>

    var context: AllPassesViewContext
    var skyChartProducer: ViewProducer<SkyChartContext, SkyChart>
    var passViewProducer: ViewProducer<PassViewContext, PassView>

    @ViewBuilder private func unwrapState<Content: View>(@ViewBuilder content: (AllPassesViewState) -> Content) -> some View {
        if let state = viewModel.state {
            content(state)
        }
    }

    private func navigationLink<Label: View>(index: Int, @ViewBuilder label: () -> Label) -> some View {
        NavigationLink(
            destination: LazyView(passViewProducer.view(PassViewContext())),
            tag: index,
            selection: Binding<Int?>(
                get: {
                    viewModel.state?.selectedPassIndex
                },
                set: {
                    viewModel.dispatch(.selectPass(index: $0))
                }
            ),
            label: label
        )
    }
    
    @ViewBuilder private func swipeActionLeftButtons(item: AllPassesViewState.Item) -> some View {
        unwrapState { state in
            if item.hasScheduledAlert {
                Button {
                    viewModel.dispatch(
                        .unscheduleNotification(pass: item.pass)
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
                                pass: item.pass,
                                satelliteName: state.satelliteInfo.satellite.commonName,
                                category: state.satelliteCategory,
                                observer: state.observer!,
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
    }

    @ViewBuilder private func passesList(_ items: [AllPassesViewState.Item]?) -> some View {
        unwrapState { state in
            if let items = items {
                if items.isEmpty {
                    Text("No passes found")
                } else {
                    ForEach(items) { item in
                        navigationLink(index: item.index) {
                            PassPreviewCell(
                                pass: item.pass,
                                referenceDate: state.julianDate,
                                indexOfPass: item.index,
                                hasScheduledAlert: item.hasScheduledAlert,
                                skyChartProducer: skyChartProducer
                            )
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 25))
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
    }

    private var visiblePassHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(LocalizedStrings.AllPassesView.Section.VisiblePasses.header)
                .font(.headline.lowercaseSmallCaps())
            Text(LocalizedStrings.AllPassesView.Section.VisiblePasses.headerCaption)
                .font(.caption)
        }
        .textCase(nil)
    }

    private var invisiblePassHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(LocalizedStrings.AllPassesView.Section.InvisiblePasses.header)
                .font(.headline.lowercaseSmallCaps())
            Text(LocalizedStrings.AllPassesView.Section.InvisiblePasses.headerCaption)
                .font(.caption)
        }
        .textCase(nil)
    }
    
    var body: some View {
        unwrapState { state in
            VStack(spacing: 0) {
                if let locationChangeWarningState = state.locationChangeWarningState {
                    AllPassesLocationChangeWarning(
                        state: locationChangeWarningState,
                        onRecalculatePasses: {
                            viewModel.dispatch(.recalculatePasses(noradIndex: state.satelliteInfo.noradIndex))
                        }
                    )
                }
                
                if state.observer != nil {
                    List {
                        Section(header: visiblePassHeader) {
                            passesList(state.visiblePasses)
                        }

                        Section(header: invisiblePassHeader) {
                            passesList(state.invisiblePasses)
                        }
                    }
                    .listStyle(.grouped)
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
            .navigationTitle(state.satelliteInfo.satellite.commonName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(alignment: .center, spacing: 4) {
                        Text(state.satelliteInfo.satellite.commonName)
                            .font(.headline)
                            .frame(alignment: .center)
                            .multilineTextAlignment(.center)
                        Text(
                            LocalizedStrings.AllPassesView.searchPassRangeToolbarText(
                                range: state.julianDateRange,
                                now: state.julianDate
                            )
                        )
                        .lineLimit(2)
                        .font(.caption)
                        .frame(alignment: .center)
                        .multilineTextAlignment(.center)
                        Color.clear
                    }
                }
            }
        }
    }
}

struct AllPassesViewContext {
}

extension ViewProducer where Context == AllPassesViewContext, ProducedView == AllPassesView {
    static func allPassesView<S: StoreType>(viewModel: S) -> ViewProducer where S.ActionType == AppAction, S.StateType == AppState {
        ViewProducer<Context, ProducedView> { context in
            AllPassesView(
                viewModel: viewModel
                    .projection(
                        action: { AppAction.allPassesView($0) },
                        state: AllPassesViewState.project(state:)
                    )
                    .asObservableViewModel(initialState: nil, emitsValue: .whenDifferent),
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
    static let tianHe: Satellite = {
        let tle = try! TLE(
            raw: """
            TIANHE
            1 48274U 21035A   21152.91865056  .00003057  00000-0  33542-4 0  9993
            2 48274  41.4713  16.3199 0005053  25.9394 109.3813 15.65195495  5304
            """
        )
        return Satellite(withTLE: tle)
    }()

    static let tianHePasses: (passes: [Pass], snapshots: BTree<Double, SatelliteSnapshot>) = {
        let sat = tianHe

        let formatter = ISO8601DateFormatter()
        let date = formatter.date(from: "2021-06-02T06:29:00-0600")!

        let observer = LatLonAlt(lat: -27.1570, lon: -109.4274, alt: 0)
        let snapshots = sat.snapshots(
            observer: observer,
            julianDateRange: date.julianDate..<date.julianDate + 2
        )

        return sat.findPasses(
            noradIndex: sat.tle.noradIndex,
            observer: observer,
            coarseSnapshots: snapshots
        )
    }()

    static var previews: some View {
        let (passes, snapshots) = tianHePasses
        let items = passes.enumerated().map { AllPassesViewState.Item(index: $0, pass: $1, hasScheduledAlert: false) }
        let itemsByVisibility = Dictionary(grouping: items, by: \.pass.visibility)
        let visiblePasses = itemsByVisibility[.visible] ?? []
        let invisiblePasses = (itemsByVisibility[.daylight] ?? []) + (itemsByVisibility[.unlit] ?? [])
        let observer = LatLonAlt(lat: -27.1570, lon: -109.4274, alt: 0)

        NavigationView {
            AllPassesView(
                viewModel: .mock(
                    state: AllPassesViewState(
                        satelliteInfo: SatelliteInfo(
                            noradIndex: 48274,
                            satellite: tianHe
                        ),
                        julianDate: Date().julianDate,
                        julianDateRange: Date().julianDate..<Date().julianDate + 1,
                        visiblePasses: visiblePasses,
                        invisiblePasses: invisiblePasses
                    )
                ),
                context: AllPassesViewContext(),
                skyChartProducer: ViewProducer<SkyChartContext, SkyChart> { context in
                    let index: Int = {
                        switch context.usage {
                        case let .preview(index: index):
                            return index
                        default:
                            fatalError()
                        }
                    }()
                    let pass = passes[index]
                    return SkyChart(
                        viewModel: .mock(
                            state: SkyChartViewState(
                                satellite: tianHe,
                                pass: pass,
                                observer: observer,
                                snapshots: SkyChartViewState.NotableSnapshots(
                                    rise: SkyChartViewState.snapshotsAroundPass(
                                        snapshots,
                                        julianDate: pass.rise.julianDate,
                                        selector: .first
                                    )!,
                                    transit: SkyChartViewState.snapshotsAroundPass(
                                        snapshots,
                                        julianDate: pass.transit.julianDate,
                                        selector: .first
                                    )!,
                                    set: SkyChartViewState.snapshotsAroundPass(
                                        snapshots,
                                        julianDate: pass.set.julianDate,
                                        selector: .last
                                    )!,
                                    illuminationChanges: BTree()
                                ),
                                referenceDate: pass.rise.julianDate,
                                quality: .preview
                            )
                        ),
                        configs: SkyChartConfigs(
                            backgroundSky: SkyChartConfigs.BackgroundSky(
                                stars: .limitedMagnitude(2),
                                showConstellationLines: false,
                                visibleBodies: [.sun, .moon],
                                bodySymbol: .symbol
                            ),
                            showAzimuthTexts: false,
                            azimuthMarkInterval: 90,
                            azimuthMarkLength: 2,
                            showDirections: false,
                            showPassInfoLabels: false
                        )
                    )
                },
                passViewProducer: .crash
            )
        }
    }
}
#endif
