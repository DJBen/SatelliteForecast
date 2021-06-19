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
    case backToAllPasses
}

struct PassViewState: Equatable {
    var tle: TLE?
    var selectedPass: PassInformation?

    static func project(state: AppState) -> PassViewState {
        PassViewState(
            tle: state.selectedSatelliteTLE,
            selectedPass: state.selectedSatellitePass
        )
    }

    static var empty: PassViewState {
        return PassViewState()
    }
}

/// The satellite detail view shows satellite passes and the sky chart during the first visible pass (if available).
struct PassView: View {
    @ObservedObject var viewModel: ObservableViewModel<PassViewAction, PassViewState>
    @Environment(\.presentationMode) var presentationMode

    var elevationGraphProducer: ViewProducer<Void, SatelliteElevationGraph>
    var skyChartProducer: ViewProducer<Void, SkyChart>

    var body: some View {
        if let tle = viewModel.state.tle {
            GeometryReader { geometry in
                let rect = geometry.frame(in: .local)
                VStack(spacing: 20) {
                    elevationGraphProducer.view()
                        .frame(alignment: .leading)
                    skyChartProducer.view()
                        .frame(height: min(rect.width, rect.height))
                    Spacer(minLength: 10)
                }
                .navigationTitle(tle.commonName)
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
                .onChange(of: presentationMode.wrappedValue.isPresented) { [presentationMode] isPresented in
                    if presentationMode.wrappedValue.isPresented && !isPresented {
                        viewModel.dispatch(.backToAllPasses)
                    }
                }
            }
        } else {
            EmptyView()
        }
    }
}

extension ViewProducer where Context == Void, ProducedView == PassView {
    static func passView<S: StoreType>(viewModel: S) -> ViewProducer where S.ActionType == AppAction, S.StateType == AppState {
        ViewProducer<Void, PassView> { noradIndex in
            PassView(
                viewModel: viewModel
                    .projection(
                        action: AppAction.passView,
                        state: PassViewState.project(state:)
                    )
                    .asObservableViewModel(initialState: .empty),
                elevationGraphProducer: ViewProducer<Void, SatelliteElevationGraph>
                    .satelliteElevationGraph(viewModel: viewModel),
                skyChartProducer: ViewProducer<Void, SkyChart>
                    .skyChart(viewModel: viewModel)
            )
        }
    }
}

import CoreLocation

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
            navigationState: .pass(noradIndex: tle.noradIndex, selectedPassIndex: 0)
        )
        PassView(
            viewModel: .mock(
                state: PassViewState(
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
                    ),
                    configs: .preset
                )
            )
        )
    }
}
