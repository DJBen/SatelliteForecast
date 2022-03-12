//
//  PassView.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/5/21.
//

import BTree
import CombineRex
import CombineRextensions
import SatelliteForecastCore
import SatelliteKit
import SwiftUI

enum PassViewAction {
}

struct PassViewState: Equatable {
    static var empty: PassViewState {
        PassViewState()
    }
    
    static func project(state: AppState) -> PassViewState {
        return PassViewState()
    }
}

/// The satellite detail view shows satellite passes and the sky chart during the first visible pass (if available).
struct PassView: View {
    @ObservedObject var viewModel: ObservableViewModel<PassViewAction, PassViewState>

    var context: PassViewContext
    var elevationGraphProducer: ViewProducer<SatelliteElevationGraphContext, SatelliteElevationGraph>
    var skyChartProducer: ViewProducer<SkyChartContext, SkyChart>

    var body: some View {
        GeometryReader { geometry in
            let rect = geometry.frame(in: .local)
            VStack(spacing: 20) {
                elevationGraphProducer.view(
                    SatelliteElevationGraphContext(
                        satelliteInfo: context.satelliteInfo,
                        julianDateRange: context.julianDateRange,
                        observer: context.observer,
                        configs: .preset
                    )
                )
                .frame(minHeight: 180, idealHeight: 240, maxHeight: 275, alignment: .leading)
                
                skyChartProducer.view(
                    SkyChartContext(
                        satelliteInfo: context.satelliteInfo,
                        snapshots: context.snapshots,
                        observer: context.observer,
                        pass: context.pass,
                        notableSnapshots: context.notableSnapshots,
                        configs: .preset,
                        quality: .full
                    )
                )
                .frame(height: min(rect.width, rect.height))
                Spacer(minLength: 10)
            }
            .clipShape(Rectangle())
            .navigationTitle(Date(julianDate: context.pass.rise.julianDate).formatted(date: .abbreviated, time: .shortened))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(alignment: .center, spacing: 4) {
                        Text(Date(julianDate: context.pass.rise.julianDate).formatted(date: .abbreviated, time: .shortened))
                            .font(.headline)
                            .frame(alignment: .center)
                            .multilineTextAlignment(.center)
                        Text(LocalizedStrings.PassView.descriptionToolbarText(for: context.pass))
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

struct PassViewContext {
    var satelliteInfo: SatelliteInfo
    var julianDateRange: ClosedRange<Double>
    var observer: LatLonAlt
    var snapshots: [SatelliteSnapshot]
    var pass: Pass
    var notableSnapshots: NotableSnapshots
}

extension ViewProducer where Context == PassViewContext, ProducedView == PassView {
    static func passView<S: StoreType>(viewModel: S) -> ViewProducer where S.ActionType == AppAction, S.StateType == AppState {
        ViewProducer<PassViewContext, PassView> { context in
            PassView(
                viewModel: viewModel
                    .projection(
                        action: AppAction.passView,
                        state: PassViewState.project(state:)
                    )
                    .asObservableViewModel(initialState: .empty, emitsValue: .whenDifferent),
                context: context,
                elevationGraphProducer: ViewProducer<SatelliteElevationGraphContext, SatelliteElevationGraph>
                    .satelliteElevationGraph(viewModel: viewModel),
                skyChartProducer: ViewProducer<SkyChartContext, SkyChart>
                    .skyChart(viewModel: viewModel)
            )
        }
    }
}

import CoreLocation

#if DEBUG
struct PassView_Previews: PreviewProvider {
    static var previews: some View {
        let tle = try! TLE(
            raw: """
            TIANHE
            1 48274U 21035A   21152.91865056  .00003057  00000-0  33542-4 0  9993
            2 48274  41.4713  16.3199 0005053  25.9394 109.3813 15.65195495  5304
            """
        )
        let julianDateRange = Date().advanced(by: -60 * 60 * 2).julianDate...Date().advanced(by: 60 * 60 * 22).julianDate
        let satelliteInfo = SatelliteInfo(tle: tle)
        // 2000 Broadway, Redwood City, CA 94063
        let observer = LatLonAlt(lat: 37.486743000691185, lon: -122.22655970246515, alt: 0)
        let snapshots = try! satelliteInfo.generateSnapshots(
            observer: observer,
            julianDateRange: julianDateRange
        )
        let passSnapshots = try! satelliteInfo.findPasses(
            observer: observer,
            coarseSnapshots: snapshots
        )
        let skyChartContext = SkyChartContext(
            satelliteInfo: satelliteInfo,
            snapshots: snapshots,
            observer: observer,
            pass: passSnapshots.first!.pass,
            notableSnapshots: passSnapshots.first!.notableSnapshots,
            configs: .preview,
            quality: .preview
        )
        let brightest100: Map<UInt, SatelliteInfo> = [
            tle.noradIndex: satelliteInfo
        ]
        let appState = AppState(
            navigationState: NavigationState(
                listNavigation: ListNavigation(
                    category: .brightest100,
                    noradIndex: tle.noradIndex,
                    selectedPassIndex: 0
                )
            ),
            skyChartResources: SkyChartResources(
                rasterizedSatellitePaths: [:],
                previewSatellitePaths: [:]
            ),
            satelliteTrails: [
                tle.noradIndex: SatelliteTrails(
                    observer: observer,
                    snapshots: snapshots,
                    passSnapshots: passSnapshots
                )
            ],
            tleLoader: TLELoaderResources(
                info: [
                    .brightest100: .loaded(brightest100)
                ]
            ),
            locationState: LocationState(
                authorizationStatus: .authorizedWhenInUse,
                currentLocation: CLLocation(observer)
            )
        )
        let context = PassViewContext(
            satelliteInfo: SatelliteInfo(tle: tle),
            julianDateRange: julianDateRange,
            observer: observer,
            snapshots: passSnapshots[0].snapshots,
            pass: passSnapshots[0].pass,
            notableSnapshots: passSnapshots[0].notableSnapshots
        )
        let elevationGraphContext = SatelliteElevationGraphContext(
            satelliteInfo: SatelliteInfo(tle: tle),
            julianDateRange: julianDateRange,
            observer: observer,
            configs: .preset
        )
        PassView(
            viewModel: .mock(
                state: PassViewState()
            ),
            context: context,
            elevationGraphProducer: .pure(
                SatelliteElevationGraph(
                    viewModel: .mock(
                        state: SatelliteElevationGraphState.project(
                            state: appState,
                            context: elevationGraphContext
                        )
                    ),
                    context: elevationGraphContext
                )
            ),
            skyChartProducer: .pure(
                SkyChart(
                    viewModel: .mock(
                        state: SkyChartViewState.project(
                            appState: appState
                        )
                    ),
                    context: skyChartContext,
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
            )
        )
        .environment(\.backgroundSkyJulianDateKey, passSnapshots[0].pass.rise.julianDate.julianDateRoundedToNearestMinute())
    }
}
#endif
