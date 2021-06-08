//
//  SatelliteListView.swift
//  SatelliteKitTests
//
//  Created by Ben Lu on 6/5/21.
//

import CombineRex
import SwiftUI
import SwiftRex
import CombineRextensions
import SatelliteKit

enum SatelliteListViewAction {
    case onAppear
    case selectSatellite(noradIndex: Int?)
}

struct SatelliteListViewState: Equatable {
    var tlesByCategory: [TLECategory: [TLE]] = [:]
    var selectedNoradIndex: Int?

    static var empty: SatelliteListViewState {
        return SatelliteListViewState()
    }

    static func project(state: Store.StateType) -> SatelliteListViewState {
        return SatelliteListViewState(
            tlesByCategory: state.tleLoaderState.tles,
            selectedNoradIndex: state.selectedSatelliteNoradIndex
        )
    }
}

struct SatelliteListView: View {
    @ObservedObject var viewModel: ObservableViewModel<SatelliteListViewAction, SatelliteListViewState>

    var detailViewProducer: ViewProducer<Void, SatelliteDetailView>

    var body: some View {
        NavigationView {
            if viewModel.state.tlesByCategory.isEmpty {
                ProgressView {
                    Text("Loading...")
                }
                .navigationTitle("Satellites")
            } else {
                List {
                    ForEach(Array(viewModel.state.tlesByCategory.keys), id: \.self) { category in
                        Section(
                            header: Text(LocalizedStrings.SatelliteListView.sectionHeader(from: category))
                        ) {
                            ForEach(viewModel.state.tlesByCategory[category] ?? [], id: \.noradIndex) { tle in
                                NavigationLink(
                                    destination: detailViewProducer.view(),
                                    tag: tle.noradIndex,
                                    selection: Binding<Int?>(
                                        get: { viewModel.state.selectedNoradIndex },
                                        set: { viewModel.dispatch(.selectSatellite(noradIndex: $0)) }
                                    )
                                ) {
                                    Text(tle.commonName)
                                }
                                .id(tle.noradIndex)
                            }
                        }
                    }
                    .navigationTitle("Satellites")
                }
            }
        }
        .onAppear {
            viewModel.dispatch(.onAppear)
        }
    }
}

extension ViewProducer where Context == Void, ProducedView == SatelliteListView {
    static func satelliteListView<S: StoreType>(viewModel: S) -> ViewProducer where S.ActionType == AppAction, S.StateType == AppState {
        ViewProducer<Context, ProducedView> {
            SatelliteListView(
                viewModel: viewModel
                    .projection(
                        action: AppAction.satelliteListView,
                        state: SatelliteListViewState.project(state:)
                    )
                    .asObservableViewModel(initialState: .empty),
                detailViewProducer: ViewProducer<Void, SatelliteDetailView>
                    .satelliteDetailView(viewModel: viewModel)
            )
        }
    }
}

struct SatelliteListView_Previews: PreviewProvider {
    static var previews: some View {
        let brightest100 = [
            try! TLE(
                raw: """
                ISS (ZARYA)
                1 25544U 98067A   21152.11066515  .00000451  00000-0  16375-4 0  9992
                2 25544  51.6453  62.2423 0003364  52.3737  88.5313 15.48937685286109
                """
            ),
            try! TLE(
                raw: """
                TIANHE
                1 48274U 21035A   21152.91865056  .00003057  00000-0  33542-4 0  9993
                2 48274  41.4713  16.3199 0005053  25.9394 109.3813 15.65195495  5304
                """
            )
        ]

        SatelliteListView(
            viewModel: .mock(
                state: SatelliteListViewState(
                    tlesByCategory: [
                        .brightest100: brightest100
                    ]
                )
            ),
            detailViewProducer: .pure(
                SatelliteDetailView(
                    viewModel: .mock(state: .empty),
                    elevationGraphProducer: .crash,
                    skyChartProducer: .crash
                )
            )
        )
    }
}
