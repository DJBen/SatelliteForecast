//
//  SatelliteDetailView.swift
//  SatelliteForcast
//
//  Created by Ben Lu on 6/5/21.
//

import CombineRex
import SwiftUI
import CombineRextensions
import SatelliteForcastCore
import SatelliteKit

enum SatelliteDetailViewAction {
    case onAppear
}

struct SatelliteDetailViewState: Equatable {
    var tle: TLE?

    static func project(state: AppState) -> SatelliteDetailViewState {
        SatelliteDetailViewState(
            tle: state.selectedSatelliteTLE
        )
    }

    static var empty: SatelliteDetailViewState {
        return SatelliteDetailViewState()
    }
}

struct SatelliteDetailView: View {
    @ObservedObject var viewModel: ObservableViewModel<SatelliteDetailViewAction, SatelliteDetailViewState>

    var elevationGraphProducer: ViewProducer<Void, SatelliteElevationGraph>
    var skyChartProducer: ViewProducer<Void, SkyChart>

    var body: some View {
        if let tle = viewModel.state.tle {
            VStack(spacing: 20) {
                Spacer()
                skyChartProducer.view()
                    .frame(idealHeight: 500, maxHeight: .infinity)

                elevationGraphProducer.view()
                    .frame(height: 250, alignment: .leading)
            }
            .navigationTitle(tle.commonName)
            .onAppear {
                viewModel.dispatch(.onAppear)
            }
        } else {
            EmptyView()
        }
    }
}

extension ViewProducer where Context == Void, ProducedView == SatelliteDetailView {
    static func satelliteDetailView<S: StoreType>(viewModel: S) -> ViewProducer where S.ActionType == AppAction, S.StateType == AppState {
        ViewProducer<Void, SatelliteDetailView> { noradIndex in
            SatelliteDetailView(
                viewModel: viewModel
                    .projection(
                        action: AppAction.satelliteDetailView,
                        state: SatelliteDetailViewState.project(state:)
                    )
                    .asObservableViewModel(initialState: .empty),
                elevationGraphProducer: ViewProducer<Void, SatelliteElevationGraph>
                    .satelliteElevationGraph(viewModel: viewModel),
                skyChartProducer: ViewProducer<Void, SkyChart>.skyChart(viewModel: viewModel)
            )
        }
    }
}

import CoreLocation

struct SatelliteDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let tle = try! TLE(
            raw: """
            TIANHE
            1 48274U 21035A   21152.91865056  .00003057  00000-0  33542-4 0  9993
            2 48274  41.4713  16.3199 0005053  25.9394 109.3813 15.65195495  5304
            """
        )
        let dateRange = Date().advanced(by: -60 * 60 * 2)..<Date().advanced(by: 60 * 60 * 22)
        let sat = Satellite(withTLE: tle)
        // 2000 Broadway, Redwood City, CA 94063
        let location = CLLocation(latitude: 37.486743000691185, longitude: -122.22655970246515)
        let snapshots = sat.snapshots(
            observer: LatLonAlt(location: location),
            dateRange: dateRange
        )
        let (passes, fineSnapshots) = sat.findPasses(observer: LatLonAlt(location: location), param: .existingSnapshots(snapshots))
        let appState = AppState(
            dateRange: dateRange,
            satelliteElevationGraphConfigs: .preset,
            satellites: [
                tle.noradIndex: SatelliteState(
                    snapshots: snapshots.merging(fineSnapshots),
                    passes: passes
                )
            ],
            tleLoaderState: TLELoaderState(
                tles: [.brightest100: [tle]]
            ),
            coreLocationState: CoreLocationState(
                authorizationStatus: .authorizedWhenInUse,
                location: location
            ),
            selectedSatelliteNoradIndex: tle.noradIndex
        )
        SatelliteDetailView(
            viewModel: .mock(
                state: SatelliteDetailViewState(
                    tle: tle
                )
            ),
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
                        state: SkyChartViewState.projectPassingMode(
                            state: appState
                        )
                    )
                )
            )
        )
    }
}
