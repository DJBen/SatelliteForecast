//
//  SatelliteListView.swift
//  SatelliteKitTests
//
//  Created by Ben Lu on 6/5/21.
//

import BTree
import CombineRex
import SwiftUI
import SwiftRex
import CombineRextensions
import SatelliteKit
import SatelliteForecastCore
import SatelliteCatalog

enum SatelliteListViewAction {
    case selectSatellite(noradIndex: Int?)
    case satelliteSearchTextChanged(String)
    case retryLoadingSatelliteList
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
    var satellites: Result<Map<Int, SatelliteInfo>, SatelliteLoaderError>?
    var satelliteSearchText: String = ""
    var category: SatelliteCategory
    var selectedNoradIndex: Int?

    static func project(state: Store.StateType) -> SatelliteListViewState? {
        guard let category = state.navigationState.selectedCategory else {
            return nil
        }

        let satellites: Result<Map<Int, SatelliteInfo>, SatelliteLoaderError>? = state.satelliteLoaderState.info[category]?.map { info in
            if state.satelliteSearchText.isEmpty {
                return info
            } else {
                var map = Map<Int, SatelliteInfo>()
                info.forEach { (noradIndex, value) in
                    if value.fitsSearchText(state.satelliteSearchText) {
                        map[noradIndex] = value
                    }
                }
                return map
            }
        }

        return SatelliteListViewState(
            satellites: satellites,
            satelliteSearchText: state.satelliteSearchText,
            category: category,
            selectedNoradIndex: state.navigationState.selectedSatelliteNoradIndex
        )
    }
}

struct SatelliteListView: View {
    @ObservedObject var viewModel: ObservableViewModel<SatelliteListViewAction, SatelliteListViewState?>

    var allPassesViewProducer: ViewProducer<AllPassesViewContext, AllPassesView>

    @ViewBuilder private func unwrapState<Content: View>(@ViewBuilder content: (SatelliteListViewState) -> Content) -> some View {
        if let state = viewModel.state {
            content(state)
        }
    }

    var destination: some View {
        allPassesViewProducer.view(
            AllPassesViewContext()
        )
    }

    @ViewBuilder func satelliteContent<Content: View, FailedContent: View>(
        @ViewBuilder contentBuilder: (Map<Int, SatelliteInfo>) -> Content,
        @ViewBuilder failedContentBuilder: (SatelliteLoaderError) -> FailedContent
    ) -> some View {
        switch viewModel.state?.satellites {
        case .none:
            ProgressView("Loading...")
        case let .success(satellites):
            contentBuilder(satellites)
        case let .failure(error):
            failedContentBuilder(error)
        }
    }

    private func satellitesView(_ satellites: Map<Int, SatelliteInfo>) -> some View {
        unwrapState { state in
            ScrollViewReader { proxy in
                List {
                    ForEach(Array(satellites.keys), id: \.self) { noradIndex in
                        NavigationLink(
                            destination: LazyView(destination),
                            tag: noradIndex,
                            selection: Binding<Int?>(
                                get: { state.selectedNoradIndex },
                                set: {
                                    print("!!! \($0)")
//                                    if $0 != nil {
//                                        viewModel.dispatch(.selectSatellite(noradIndex: $0))
//                                    }
                                    viewModel.dispatch(.selectSatellite(noradIndex: $0))
                                }
                            )
                        ) {
                            SatelliteCell(info: satellites[noradIndex]!)
                        }
                        .id(noradIndex)
                    }
                }
                .onAppear {
                    if let noradIndex = state.selectedNoradIndex {
                        proxy.scrollTo(noradIndex, anchor: nil)
                    }
                }
                .onChange(of: state.selectedNoradIndex) { newValue in
                    if let noradIndex = newValue {
                        proxy.scrollTo(noradIndex, anchor: nil)
                    }
                }
            }
            .searchable(
                text: Binding<String>(
                    get: {
                        state.satelliteSearchText
                    }, set: {
                        viewModel.dispatch(.satelliteSearchTextChanged($0))
                    }
                ),
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Filter by name, ID, country, year..."
            )
            .listStyle(.insetGrouped)
            .navigationTitle("Satellites")
        }
    }

    private func failureView(_ error: Error) -> some View {
        VStack(spacing: 16) {
            Text(error.localizedDescription)

            Button(
                "Retry",
                action: { viewModel.dispatch(.retryLoadingSatelliteList) }
            )
            .font(Font.headline)
            .foregroundColor(Color(UIColor.systemBlue))
        }
    }

    var body: some View {
        satelliteContent(
            contentBuilder: { satellites in
                satellitesView(satellites)
            },
            failedContentBuilder: { error in
                failureView(error)
            }
        )
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
                    .asObservableViewModel(initialState: nil, emitsValue: .whenDifferent),
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
        .reduce(into: Map<Int, SatelliteInfo>(), { $0[$1.noradIndex] = $1 })

        SatelliteListView(
            viewModel: .mock(
                state: SatelliteListViewState(
                    satellites: .success(brightest100),
                    category: .brightest100,
                    selectedNoradIndex: nil
                )
            ),
            allPassesViewProducer: .pure(
                AllPassesView(
                    viewModel: .mock(
                        state: nil
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
