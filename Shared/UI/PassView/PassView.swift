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
    case onAppear
}

struct PassViewState: Equatable {
    var info: SatelliteInfo
    var pass: Pass

    static func project(state: AppState) -> PassViewState? {
        guard let info = state.navigationState.selectedSatelliteNoradIndex.flatMap({ state.satelliteLoaderState[$0] }),
              let selectedPass = state.selectedSatellitePass else {
            return nil
        }
        return PassViewState(
            info: info,
            pass: selectedPass
        )
    }
}

/// The satellite detail view shows satellite passes and the sky chart during the first visible pass (if available).
struct PassView: View {
    @ObservedObject var viewModel: ObservableViewModel<PassViewAction, PassViewState?>

    var context: PassViewContext
    var elevationGraphProducer: ViewProducer<Void, SatelliteElevationGraph>
    var skyChartProducer: ViewProducer<SkyChartContext, SkyChart>

    var body: some View {
        if let state = viewModel.state {
            GeometryReader { geometry in
                let rect = geometry.frame(in: .local)
                VStack(spacing: 20) {
                    elevationGraphProducer.view()
                        .frame(height: 250, alignment: .leading)
                    skyChartProducer.view(
                        SkyChartContext(usage: .full)
                    )
                    .frame(height: min(rect.width, rect.height))
                    Spacer(minLength: 10)
                }
                .clipShape(Rectangle())
                .navigationTitle(Date(julianDate: state.pass.rise.julianDate).formatted(date: .abbreviated, time: .shortened))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        VStack(alignment: .center, spacing: 4) {
                            Text(Date(julianDate: state.pass.rise.julianDate).formatted(date: .abbreviated, time: .shortened))
                                .font(.headline)
                                .frame(alignment: .center)
                                .multilineTextAlignment(.center)
                            Text(LocalizedStrings.PassView.descriptionToolbarText(for: state.pass))
                                .lineLimit(2)
                                .font(.caption)
                                .frame(alignment: .center)
                                .multilineTextAlignment(.center)
                            Color.clear
                        }
                    }
                }
            }
            .onAppear {
                viewModel.dispatch(.onAppear)
            }
        }
    }
}

struct PassViewContext {
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
                    .asObservableViewModel(initialState: nil, emitsValue: .whenDifferent),
                context: context,
                elevationGraphProducer: ViewProducer<Void, SatelliteElevationGraph>
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
        let julianDateRange = Date().advanced(by: -60 * 60 * 2).julianDate..<Date().advanced(by: 60 * 60 * 22).julianDate
        let sat = Satellite(withTLE: tle)
        // 2000 Broadway, Redwood City, CA 94063
        let location = CLLocation(latitude: 37.486743000691185, longitude: -122.22655970246515)
        let snapshots = sat.snapshots(
            observer: LatLonAlt(location: location),
            julianDateRange: julianDateRange
        )
        let (passes, fineSnapshots) = sat.findPasses(
            noradIndex: tle.noradIndex,
            observer: LatLonAlt(location: location),
            coarseSnapshots: snapshots
        )
        let brightest100: Map<Int, SatelliteInfo> = [tle.noradIndex: SatelliteInfo(noradIndex: tle.noradIndex, satellite: sat)]
        let appState = AppState(
            skyChartState: SkyChartResources(
                rasterizedSatellitePaths: [:],
                previewSatellitePaths: [:],
                rasterizedBackgroundSky: [:],
                previewBackgroundSkies: [:]
            ),
            satellites: [
                tle.noradIndex: SatelliteTrails(
                    snapshots: snapshots.union(fineSnapshots, by: .groupingMatches),
                    passes: passes
                )
            ],
            satelliteLoaderState: SatelliteLoaderState(
                info: [
                    .brightest100: .success(brightest100)
                ]
            ),
            locationState: LocationState(
                authorizationStatus: .authorizedWhenInUse,
                currentLocation: location
            ),
            julianDateRange: julianDateRange,
            navigationState: .pass(category: .brightest100, noradIndex: tle.noradIndex, selectedPassIndex: 0)
        )
        PassView(
            viewModel: .mock(
                state: PassViewState(
                    info: SatelliteInfo(noradIndex: tle.noradIndex, satellite: sat),
                    pass: passes[0]
                )
            ),
            context: PassViewContext(),
            elevationGraphProducer: .pure(
                SatelliteElevationGraph(
                    viewModel: .mock(
                        state: SatelliteElevationGraphState.project(
                            state: appState
                        )
                    )
                )
            ),
            skyChartProducer: .pure(
                SkyChart(
                    viewModel: .mock(
                        state: SkyChartViewState.project(
                            state: appState,
                            backgroundSkyConfigs: .preset
                        )
                    ),
                    configs: .preset
                )
            )
        )
    }
}
#endif
