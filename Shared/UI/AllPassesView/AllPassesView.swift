//
//  AllPassesView.swift
//  SatelliteForcast (iOS)
//
//  Created by Ben Lu on 6/14/21.
//

import BTree
import CombineRex
import CombineRextensions
import SatelliteForcastCore
import SatelliteKit
import SwiftUI

enum AllPassesViewAction {
    
}

struct AllPassesViewState: Equatable {
    struct Item: Equatable, Identifiable {
        let index: Int
        let pass: PassInformation

        var id: Int {
            return index
        }
    }
    var visiblePasses: [Item] = []
    var invisiblePasses: [Item] = []

    static func project(state: AppState) -> AllPassesViewState {
        guard let satelliteState = state.satellites[state.selectedSatelliteNoradIndex!] else {
            return .empty
        }
        let items = satelliteState.passes.enumerated().map { Item(index: $0, pass: $1) }
        let itemsByVisibility = Dictionary(grouping: items, by: \.pass.visibility)
        let visiblePasses = itemsByVisibility[.visible] ?? []
        let invisiblePasses = (itemsByVisibility[.daylight] ?? []) + (itemsByVisibility[.unlit] ?? [])
        return AllPassesViewState(
            visiblePasses: visiblePasses
                .sorted { $0.pass.rise.julianDate < $1.pass.rise.julianDate },
            invisiblePasses: invisiblePasses
                .sorted { $0.pass.rise.julianDate < $1.pass.rise.julianDate }
        )
    }

    static var empty: AllPassesViewState {
        return AllPassesViewState()
    }
}

struct AllPassesView: View {
    @ObservedObject var viewModel: ObservableViewModel<AllPassesViewAction, AllPassesViewState>

    var skyChartProducer: ViewProducer<Int, SkyChart>

    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(minimum: 180), spacing: 0),
                    GridItem(.flexible(minimum: 180), spacing: 0)
                ],
                alignment: .center,
                spacing: 16,
                pinnedViews: [.sectionHeaders, .sectionFooters]
            ) {
                Section(header: Text("Visible Passes").font(.title)) {
                    ForEach(viewModel.state.visiblePasses) { item in
                        PassPreviewCell(
                            pass: item.pass,
                            indexOfPass: item.index,
                            skyChartProducer: skyChartProducer
                        )
                        .frame(height: 110)
                    }
                }

                Section(header: Text("Invisible Passes").font(.title)) {
                    ForEach(viewModel.state.invisiblePasses) { item in
                        PassPreviewCell(
                            pass: item.pass,
                            indexOfPass: item.index,
                            skyChartProducer: skyChartProducer
                        )
                        .frame(height: 110)
                    }
                }
            }
        }
    }
}

extension ViewProducer where Context == Void, ProducedView == AllPassesView {
    static func allPassesView<S: StoreType>(viewModel: S) -> ViewProducer where S.ActionType == AppAction, S.StateType == AppState {
        ViewProducer<Context, ProducedView> {
            AllPassesView(
                viewModel: viewModel
                    .projection(
                        action: { _ -> AppAction in },
                        state: AllPassesViewState.project(state:)
                    )
                    .asObservableViewModel(initialState: .empty),
                skyChartProducer: ViewProducer<Int, SkyChart>
                    .skyChartAsPreview(viewModel: viewModel)
            )
        }
    }
}

struct AllPassesView_Previews: PreviewProvider {
    static let tianHePasses: (passes: [PassInformation], snapshots: Map<Double, SatelliteSnapshot>) = {
        let tle = try! TLE(
            raw: """
            TIANHE
            1 48274U 21035A   21152.91865056  .00003057  00000-0  33542-4 0  9993
            2 48274  41.4713  16.3199 0005053  25.9394 109.3813 15.65195495  5304
            """
        )
        let sat = Satellite(withTLE: tle)

        let formatter = ISO8601DateFormatter()
        let date = formatter.date(from: "2021-06-02T06:29:00-0600")!

        let observer = LatLonAlt(lat: -27.1570, lon: -109.4274, alt: 0)
        let snapshots = sat.snapshots(
            observer: observer,
            julianDateRange: date.julianDate..<date.julianDate + 2
        )

        return sat.findPasses(
            observer: observer,
            coarseSnapshots: snapshots
        )
    }()

    static var previews: some View {
        let (passes, snapshots) = tianHePasses
        let items = passes.enumerated().map { AllPassesViewState.Item(index: $0, pass: $1) }
        let itemsByVisibility = Dictionary(grouping: items, by: \.pass.visibility)
        let visiblePasses = itemsByVisibility[.visible] ?? []
        let invisiblePasses = (itemsByVisibility[.daylight] ?? []) + (itemsByVisibility[.unlit] ?? [])

        AllPassesView(
            viewModel: .mock(
                state: AllPassesViewState(
                    visiblePasses: visiblePasses,
                    invisiblePasses: invisiblePasses
                )
            ),
            skyChartProducer: ViewProducer<Int, SkyChart> { index in
                let pass = passes[index]
                let snapshotsDuringPass = snapshots.submap(from: pass.rise.julianDate, through: pass.set.julianDate)
                return SkyChart(
                    viewModel: .mock(
                        state: SkyChartViewState(
                            mode: .pass(
                                pass,
                                snapshotsDuringPass: snapshotsDuringPass,
                                observer: LatLonAlt(lat: -27.1570, lon: -109.4274, alt: 0)
                            )
                        )
                    ),
                    configs: SkyChartConfigs(
                        backgroundSky: SkyChartConfigs.BackgroundSky(
                            showStars: false,
                            showConstellationLines: false,
                            visibileBodies: [.sun, .moon],
                            bodySymbol: .symbol
                        ),
                        showAzimuthTexts: false,
                        azimuthMarkInterval: 90,
                        azimuthMarkLength: 2,
                        showDirections: false,
                        showPassInfoLabels: false
                    )
                )
            }
        )
    }
}
