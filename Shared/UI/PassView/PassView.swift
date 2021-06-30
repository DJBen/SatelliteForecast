//
//  PassView.swift
//  SatelliteForcast
//
//  Created by Ben Lu on 6/5/21.
//

import CombineRex
import CombineRextensions
import SatelliteForcastCore
import SatelliteKit
import SwiftUI

enum PassViewAction {
    case onAppear
}

struct PassViewState: Equatable {
    var info: SatelliteInfo?
    var selectedPass: Pass?

    static func project(state: AppState) -> PassViewState {
        PassViewState(
            info: state.selectedSatelliteInfo,
            selectedPass: state.selectedSatellitePass
        )
    }

    static var empty: PassViewState {
        return PassViewState()
    }
}

/// The satellite detail view shows satellite passes and the sky chart during the first visible pass (if available).
struct PassView: View, Equatable {
    static func == (lhs: PassView, rhs: PassView) -> Bool {
        lhs.viewModel.state == rhs.viewModel.state
    }

    @ObservedObject var viewModel: ObservableViewModel<PassViewAction, PassViewState>

    var context: PassViewContext
    var elevationGraphProducer: ViewProducer<Void, SatelliteElevationGraph>
    var skyChartProducer: ViewProducer<SkyChartContext, SkyChart>

    var body: some View {
        if let info = viewModel.state.info {
            GeometryReader { geometry in
                let rect = geometry.frame(in: .local)
                VStack(spacing: 20) {
                    elevationGraphProducer.view()
                        .frame(alignment: .leading)
                    skyChartProducer.view(
                        SkyChartContext(usage: .full)
                    )
                    .equatable()
                    .frame(height: min(rect.width, rect.height))
                    Spacer(minLength: 10)
                }
                .clipShape(Rectangle())
                .navigationTitle(info.satellite.commonName)
                .navigationBarTitleDisplayMode(.inline)
                .onAppear {
                    viewModel.dispatch(.onAppear)
                }
                .toolbar {
                    ToolbarItem(placement: .bottomBar) {
                        Button(action: {

                        }, label: {
                            Image(systemName: "square.stack.3d.up")
                        })
                    }
                }
            }
        } else {
            EmptyView()
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
                    .asObservableViewModel(initialState: .empty),
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
        let appState = AppState(
            julianDateRange: julianDateRange,
            satelliteElevationGraphConfigs: .preset,
            satellites: [
                tle.noradIndex: SatelliteTrails(
                    snapshots: snapshots.union(fineSnapshots, by: .groupingMatches),
                    passes: passes
                )
            ],
            satelliteLoaderState: SatelliteLoaderState(
                info: [.brightest100: [SatelliteInfo(noradIndex: tle.noradIndex, satellite: sat)]]
            ),
            coreLocationState: CoreLocationState(
                authorizationStatus: .authorizedWhenInUse,
                location: location
            ),
            navigationState: .pass(category: .brightest100, noradIndex: tle.noradIndex, selectedPassIndex: 0)
        )
        PassView(
            viewModel: .mock(
                state: PassViewState(
                    info: SatelliteInfo(noradIndex: tle.noradIndex, satellite: sat)
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
                            state: appState
                        )
                    ),
                    configs: .preset,
                    usage: .preview
                )
            )
        )
    }
}
#endif
