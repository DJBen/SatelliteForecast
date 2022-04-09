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
import SatelliteForecast
import SatelliteForecastImpl
import SatelliteCatalog

public enum SatelliteListViewAction {
    public struct SelectSatelliteParams {
        public let noradIndex: UInt
        public let satelliteInfo: SatelliteInfo
        public let julianDateRange: ClosedRange<Double>
        public let observer: LatLonAlt?

        public init(
            noradIndex: UInt,
            satelliteInfo: SatelliteInfo,
            julianDateRange: ClosedRange<Double>,
            observer: LatLonAlt?
        ) {
            self.noradIndex = noradIndex
            self.satelliteInfo = satelliteInfo
            self.julianDateRange = julianDateRange
            self.observer = observer
        }
    }
    case selectSatellite(SelectSatelliteParams?)
    case satelliteSearchTextChanged(String)
    case retryLoadingSatelliteList(category: SatelliteCategory)
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
        } else if elements.commonName.lowercased().contains(searchText) {
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

public struct SatelliteListViewState {
    public var satelliteInfo: [SatelliteCategory: Loadable<Map<UInt, SatelliteInfo>, ElementsLoaderError>] = [:]
    public var satelliteSearchText: String = ""
    public var selectedNoradIndex: UInt?

    public init(satelliteInfo: [SatelliteCategory : Loadable<Map<UInt, SatelliteInfo>, ElementsLoaderError>] = [:], satelliteSearchText: String = "", selectedNoradIndex: UInt? = nil) {
        self.satelliteInfo = satelliteInfo
        self.satelliteSearchText = satelliteSearchText
        self.selectedNoradIndex = selectedNoradIndex
    }
}

extension SatelliteListViewState: Equatable {}

public struct SatelliteListViewContext {
    public let category: SatelliteCategory
    public let julianDateRange: ClosedRange<Double>
    public let observer: LatLonAlt?
    public let julianDateProvider: () -> Double

    public init(category: SatelliteCategory, julianDateRange: ClosedRange<Double>, observer: LatLonAlt?, julianDateProvider: @escaping () -> Double) {
        self.category = category
        self.julianDateRange = julianDateRange
        self.observer = observer
        self.julianDateProvider = julianDateProvider
    }
}

public struct SatelliteListView: View {
    @ObservedObject var viewModel: ObservableViewModel<SatelliteListViewAction, SatelliteListViewState>
    let context: SatelliteListViewContext
    let allPassesViewProducer: ViewProducer<AllPassesViewContext, AllPassesView>

    public init(
        viewModel: ObservableViewModel<SatelliteListViewAction, SatelliteListViewState>,
        context: SatelliteListViewContext,
        allPassesViewProducer: ViewProducer<AllPassesViewContext, AllPassesView>
    ) {
        self.viewModel = viewModel
        self.context = context
        self.allPassesViewProducer = allPassesViewProducer
    }

    @ViewBuilder func satelliteContent<Content: View, FailedContent: View>(
        @ViewBuilder contentBuilder: (Map<UInt, SatelliteInfo>) -> Content,
        @ViewBuilder failedContentBuilder: (ElementsLoaderError) -> FailedContent
    ) -> some View {
        let satellites: Loadable<Map<UInt, SatelliteInfo>, ElementsLoaderError> = viewModel.state.satelliteInfo[context.category]?.map { info in
            let searchText = viewModel.state.satelliteSearchText
            if searchText.isEmpty {
                return info
            } else {
                var map = Map<UInt, SatelliteInfo>()
                info.forEach { (noradIndex, value) in
                    if value.fitsSearchText(searchText) {
                        map[noradIndex] = value
                    }
                }
                return map
            }
        } ?? .notLoaded
        Group {
            switch satellites {
            case .notLoaded:
                Text(verbatim: "The satellites are not loaded.")
            case .loading:
                ProgressView("Loading...")
            case let .loaded(satellites):
                contentBuilder(satellites)
            case let .failed(error):
                failedContentBuilder(error)
            }
        }
    }

    private func satellitesView(_ satellites: Map<UInt, SatelliteInfo>) -> some View {
        ScrollViewReader { proxy in
            List {
                ForEach(Array(satellites.keys), id: \.self) { noradIndex in
                    let satelliteInfo = satellites[noradIndex]!
                    NavigationLink(
                        destination: LazyView(
                            allPassesViewProducer.view(
                                AllPassesViewContext(
                                    satelliteInfo: satelliteInfo,
                                    julianDateRange: context.julianDateRange,
                                    observer: context.observer,
                                    julianDateProvider: context.julianDateProvider
                                )
                            )
                        ),
                        rowTag: noradIndex,
                        viewModel: viewModel,
                        pathToSelectedRowTag: \.selectedNoradIndex,
                        onOpen: { noradIndex in
                            .selectSatellite(
                                SatelliteListViewAction.SelectSatelliteParams(
                                    noradIndex: noradIndex,
                                    satelliteInfo: satelliteInfo,
                                    julianDateRange: context.julianDateRange,
                                    observer: context.observer
                                )
                            )
                        },
                        onClose: .selectSatellite(nil),
                        label: {
                            SatelliteCell(info: satelliteInfo)
                        }
                    )
                    .id(noradIndex)
                }
            }
            .onAppear {
                if let noradIndex = viewModel.state.selectedNoradIndex {
                    proxy.scrollTo(noradIndex, anchor: nil)
                }
            }
            .onChange(of: viewModel.state.selectedNoradIndex) { newValue in
                if let noradIndex = newValue {
                    proxy.scrollTo(noradIndex, anchor: nil)
                }
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
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Filter by name, ID, country, year..."
        )
        .listStyle(.insetGrouped)
        .navigationTitle("Satellites")
    }

    private func failureView(_ error: Error) -> some View {
        VStack(spacing: 16) {
            Text(error.localizedDescription)

            Button(
                "Retry",
                action: {
                    viewModel.dispatch(
                        .retryLoadingSatelliteList(
                            category: context.category
                        )
                    )
                }
            )
            .font(Font.headline)
            .foregroundColor(Color(UIColor.systemBlue))
        }
    }

    public var body: some View {
        satelliteContent(
            contentBuilder: { satellites in
                satellitesView(
                    satellites
                )
            },
            failedContentBuilder: { error in
                failureView(error)
            }
        )
    }
}

#if DEBUG
struct SatelliteListView_Previews: PreviewProvider {
    static var previews: some View {
        let brightest100 = [
            try! Elements(
                raw: """
                ISS (ZARYA)
                1 25544U 98067A   21152.11066515  .00000451  00000-0  16375-4 0  9992
                2 25544  51.6453  62.2423 0003364  52.3737  88.5313 15.48937685286109
                """
            ),
            try! Elements(
                raw: """
                TIANHE
                1 48274U 21035A   21152.91865056  .00003057  00000-0  33542-4 0  9993
                2 48274  41.4713  16.3199 0005053  25.9394 109.3813 15.65195495  5304
                """
            )
        ]
        .map {
            SatelliteInfo(
                elements: $0,
                satCat: SatCat.with(noradCatID: Int($0.noradIndex)),
                ucsSat: UCSSat.with(noradCatID: Int($0.noradIndex))
            )
        }
        .reduce(into: Map<UInt, SatelliteInfo>(), { $0[$1.noradIndex] = $1 })

        SatelliteListView(
            viewModel: .mock(
                state: SatelliteListViewState(
                    satelliteInfo: [.brightest100: .loaded(brightest100)],
                    selectedNoradIndex: nil
                )
            ),
            context: SatelliteListViewContext(
                category: .brightest100,
                julianDateRange: Date(daysSince1950: 1000).julianDate...Date(daysSince1950: 1002).julianDate,
                observer: nil,
                julianDateProvider: { Date(daysSince1950: 1001).julianDate }
            ),
            allPassesViewProducer: .crash
        )
    }
}
#endif
