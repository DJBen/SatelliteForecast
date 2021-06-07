//
//  SatelliteDetailView.swift
//  SatelliteForcast
//
//  Created by Ben Lu on 6/5/21.
//

import CombineRex
import SwiftUI
import CombineRextensions
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

    var body: some View {
        NavigationView {
            if let tle = viewModel.state.tle {
                VStack {
                    elevationGraphProducer.view()
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
                    .satelliteElevationGraph(viewModel: viewModel)
            )
        }
    }
}

struct SatelliteDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let tle = try! TLE(
            raw: """
            TIANHE
            1 48274U 21035A   21152.91865056  .00003057  00000-0  33542-4 0  9993
            2 48274  41.4713  16.3199 0005053  25.9394 109.3813 15.65195495  5304
            """
        )
        let appState = AppState(
            dateRange: Date().advanced(by: -60 * 60 * 2)..<Date().advanced(by: 60 * 60 * 22),
            satelliteElevationGraphConfigs: .preset,
            tleLoaderState: TLELoaderState(
                tles: [.brightest100: [tle]]
            ),
            coreLocationState: .empty,
            selectedSatelliteNoradIndex: "48274"
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
            )
        )
    }
}
