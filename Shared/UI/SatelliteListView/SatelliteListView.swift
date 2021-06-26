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
import SatelliteForcastCore
import SatelliteCatalog

enum SatelliteListViewAction {
    case onAppear
    case selectSatellite(noradIndex: Int?)
}

struct SatelliteListViewState: Equatable {
    var satellitesByCategory: [SatelliteCategory: [SatelliteInfo]] = [:]
    var selectedNoradIndex: Int?

    static var empty: SatelliteListViewState {
        return SatelliteListViewState()
    }

    static func project(state: Store.StateType) -> SatelliteListViewState {
        return SatelliteListViewState(
            satellitesByCategory: state.satelliteLoaderState.info,
            selectedNoradIndex: state.selectedSatelliteNoradIndex
        )
    }
}

struct SatelliteListView: View {
    @ObservedObject var viewModel: ObservableViewModel<SatelliteListViewAction, SatelliteListViewState>

    var allPassesViewProducer: ViewProducer<AllPassesViewContext, AllPassesView>

    var destination: some View {
        allPassesViewProducer.view(
            AllPassesViewContext()
        )
        .equatable()
    }

    var body: some View {
        NavigationView {
            if viewModel.state.satellitesByCategory.isEmpty {
                ProgressView {
                    Text("Loading...")
                }
                .navigationTitle("Satellites")
            } else {
                List {
                    ForEach(Array(viewModel.state.satellitesByCategory.keys), id: \.self) { category in
                        Section(
                            header: Text(LocalizedStrings.SatelliteListView.sectionHeader(from: category))
                        ) {
                            ForEach(viewModel.state.satellitesByCategory[category] ?? [], id: \.noradIndex) { info in
                                NavigationLink(
                                    destination: destination,
                                    tag: info.noradIndex,
                                    selection: Binding<Int?>(
                                        get: { viewModel.state.selectedNoradIndex },
                                        set: { viewModel.dispatch(.selectSatellite(noradIndex: $0)) }
                                    )
                                ) {
                                    SatelliteCell(info: info)
                                }
                                .id(info.noradIndex)
                            }
                        }
                    }
                    .navigationTitle("Satellites")
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            viewModel.dispatch(.onAppear)
        }
    }
}

extension ViewProducer where Context == Void, ProducedView == SatelliteListView {
    static func satelliteListView<S: StoreType>(viewModel: S) -> ViewProducer where S.ActionType == AppAction, S.StateType == AppState {
        ViewProducer<Context, ProducedView> { context in
            SatelliteListView(
                viewModel: viewModel
                    .projection(
                        action: AppAction.satelliteListView,
                        state: SatelliteListViewState.project(state:)
                    )
                    .asObservableViewModel(initialState: .empty),
                allPassesViewProducer: ViewProducer<AllPassesViewContext, AllPassesView>
                    .allPassesView(viewModel: viewModel)
            )
        }
    }
}

#if DEBUG
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
        .map {
            SatelliteInfo(
                noradIndex: $0.noradIndex,
                satellite: Satellite(withTLE: $0),
                satCat: SatCat.with(noradCatID: $0.noradIndex),
                ucsSat: UCSSat.with(noradCatID: $0.noradIndex)
            )
        }

        SatelliteListView(
            viewModel: .mock(
                state: SatelliteListViewState(
                    satellitesByCategory: [
                        .brightest100: brightest100
                    ]
                )
            ),
            allPassesViewProducer: .pure(
                AllPassesView(
                    viewModel: .mock(
                        state: AllPassesViewState()
                    ),
                    context: AllPassesViewContext(),
                    skyChartProducer: .crash,
                    passViewProducer: .crash
                )
            )
        )
    }
}
#endif
