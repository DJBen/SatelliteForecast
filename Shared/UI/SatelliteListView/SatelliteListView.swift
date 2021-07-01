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
    case satelliteSearchTextChanged(String)
}

private let yearFormatter: DateFormatter = {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy"
    return dateFormatter
}()

fileprivate extension SatelliteInfo {
    func fitsSearchText(_ searchText: String) -> Bool {
        guard !searchText.isEmpty else {
            return true
        }

        let searchText = searchText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        if String(noradIndex).contains(searchText) {
            return true
        } else if satellite.commonName.lowercased().contains(searchText) {
            return true
        } else if satCat?.cosparID.lowercased().contains(searchText) ?? false {
            return true
        } else if satCat?.launchSite.code.lowercased().contains(searchText) ?? false {
            return true
        } else if let date = satCat?.launchDate, yearFormatter.string(from: date) == searchText {
            return true
        } else if let ucsSat = ucsSat {
            return ucsSat.name.lowercased().contains(searchText)
            || ucsSat.countryOfOperatorOrOwner.lowercased().contains(searchText)
        }

        return false
    }
}

struct SatelliteListViewState: Equatable {
    var satellites: [SatelliteInfo] = []
    var satelliteSearchText: String = ""
    var indexPath: NavigationIndexPath?

    static var empty: SatelliteListViewState {
        return SatelliteListViewState()
    }

    static func project(state: Store.StateType) -> SatelliteListViewState {
        let allSatellites = state.navigationState.selectedCategory
            .flatMap { state.satelliteLoaderState.info[$0] } ?? []
        let filteredSatellites = state.satelliteSearchText.isEmpty ? allSatellites : allSatellites.filter { $0.fitsSearchText(state.satelliteSearchText) }

        return SatelliteListViewState(
            satellites: filteredSatellites,
            satelliteSearchText: state.satelliteSearchText,
            indexPath: state.navigationState.indexPath
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

    private struct SatelliteNavTag: Equatable, Hashable {
        let category: SatelliteCategory?
        let noradIndex: Int?

        init(_ navigationIndexPath: NavigationIndexPath) {
            category = navigationIndexPath.category
            noradIndex = navigationIndexPath.noradIndex
        }

        init(category: SatelliteCategory?, noradIndex: Int?) {
            self.category = category
            self.noradIndex = noradIndex
        }
    }

    func progressView<Content: View>(@ViewBuilder builder: () -> Content) -> some View {
        if viewModel.state.satellites.isEmpty && viewModel.state.satelliteSearchText.isEmpty {
            return AnyView(ProgressView("Loading..."))
        } else {
            return AnyView(builder())
        }
    }

    var body: some View {
        progressView {
            List {
                ForEach(viewModel.state.satellites, id: \.noradIndex) { info in
                    NavigationLink(
                        destination: destination,
                        tag: SatelliteNavTag(
                            category: viewModel.state.indexPath?.category,
                            noradIndex: info.noradIndex
                        ),
                        selection: Binding<SatelliteNavTag?>(
                            get: { viewModel.state.indexPath.map(SatelliteNavTag.init) },
                            set: {
                                viewModel.dispatch(.selectSatellite(noradIndex: $0?.noradIndex))
                            }
                        )
                    ) {
                        SatelliteCell(info: info)
                    }
                    .id(info.noradIndex)
                }
            }
            .searchable(
                text: Binding<String>(
                    get: {
                        viewModel.state.satelliteSearchText
                    }, set: {
                        viewModel.dispatch(.satelliteSearchTextChanged($0))
                    }
                ),
                prompt: "Filter by name, ID, country, year..."
            )
            .navigationTitle("Satellites")
        }
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
                    satellites: brightest100
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
