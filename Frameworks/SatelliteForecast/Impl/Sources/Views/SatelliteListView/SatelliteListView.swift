//
//  SatelliteListView.swift
//  SatelliteKitTests
//
//  Created by Ben Lu on 6/5/21.
//

import BTree
@preconcurrency import CombineRex
import SwiftUI
import SwiftRex
@preconcurrency import CombineRextensions
@preconcurrency import SatelliteKit
import SatelliteForecast
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

    case loadSatellite(SelectSatelliteParams?)
    case selectSatellite(SelectSatelliteParams, category: SatelliteCategory)
    case searchSatellites(String, category: SatelliteCategory)
    case retryLoadingSatelliteList(category: SatelliteCategory)
}

public enum SatelliteListViewOutput {
    case filteredSatellites(
        Map<UInt, SatelliteInfo>?,
        searchText: String,
        category: SatelliteCategory
    )
}

public struct SatelliteListViewState {
    public var navigationPath: NavigationPath = .init()
    public var satelliteInfo: [SatelliteCategory: Loadable<Map<UInt, SatelliteInfo>, ElementsLoaderError>] = [:]
    public var filteredSatellites: Map<UInt, SatelliteInfo>?

    public init(
        navigationPath: NavigationPath = .init(),
        satelliteInfo: [SatelliteCategory : Loadable<Map<UInt, SatelliteInfo>, ElementsLoaderError>] = [:],
        filteredSatellites: Map<UInt, SatelliteInfo>? = nil
    ) {
        self.navigationPath = navigationPath
        self.satelliteInfo = satelliteInfo
        self.filteredSatellites = filteredSatellites
    }
}

extension SatelliteListViewState: Equatable {}

public struct SatelliteListSelectedSatellite {
    public var noradIndex: UInt

    public init(
        noradIndex: UInt
    ) {
        self.noradIndex = noradIndex
    }
}

extension SatelliteListSelectedSatellite: Equatable, Hashable, Codable {
}

public struct SatelliteListViewContext {
    public let category: SatelliteCategory
    public let julianDateRange: ClosedRange<Double>
    public let observer: LatLonAlt?
    public let julianDateProvider: () -> Double

    public init(
        category: SatelliteCategory,
        julianDateRange: ClosedRange<Double>,
        observer: LatLonAlt?,
        julianDateProvider: @escaping () -> Double
    ) {
        self.category = category
        self.julianDateRange = julianDateRange
        self.observer = observer
        self.julianDateProvider = julianDateProvider
    }
}

class TextFieldObserver : ObservableObject {
    @Published var debouncedText = ""
    @Published var searchText = ""

    init(delay: DispatchQueue.SchedulerTimeType.Stride) {
        $searchText
            .debounce(for: delay, scheduler: DispatchQueue.main)
            .assign(to: &$debouncedText)
    }
}

public struct SatelliteListView: View {
    @ObservedObject var viewModel: ObservableViewModel<SatelliteListViewAction, SatelliteListViewState>
    let context: SatelliteListViewContext
    let allPassesViewProducer: ViewProducer<AllPassesViewContext, AllPassesView>

    @StateObject var textObserver = TextFieldObserver(delay: 0.5)

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
        if let filteredSatellites = viewModel.state.filteredSatellites {
            contentBuilder(filteredSatellites)
        } else {
            switch (viewModel.state.satelliteInfo[context.category] ?? .notLoaded) {
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
        List {
            ForEach(Array(satellites.keys), id: \.self) { noradIndex in
                let satelliteInfo = satellites[noradIndex]!
                NavigationLink(value: SatelliteListSelectedSatellite(noradIndex: noradIndex)) {
                    SatelliteCell(info: satelliteInfo)
                }
            }
        }
        .navigationDestination(for: SatelliteListSelectedSatellite.self) { satellite in
            LazyView {
                allPassesViewProducer.view(
                    AllPassesViewContext(
                        satelliteInfo: viewModel.state.satelliteInfo[context.category]!.content![satellite.noradIndex]!,
                        julianDateRange: context.julianDateRange,
                        observer: context.observer,
                        julianDateProvider: context.julianDateProvider
                    )
                )
                .onAppear {
                    viewModel.dispatch(
                        .loadSatellite(
                            SatelliteListViewAction.SelectSatelliteParams(
                                noradIndex: satellite.noradIndex,
                                satelliteInfo: viewModel.state.satelliteInfo[context.category]!.content![satellite.noradIndex]!,
                                julianDateRange: context.julianDateRange,
                                observer: context.observer
                            )
                        )
                    )
                }
            }
        }
        .listStyle(.insetGrouped)
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
        return satelliteContent(
            contentBuilder: { satellites in
                satellitesView(
                    satellites
                )
            },
            failedContentBuilder: failureView
        )
        .navigationTitle("Satellites")
        .searchable(
            text: $textObserver.searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Filter by name, ID, country, year..."
        )
        .onChange(of: textObserver.debouncedText) { _, searchText in
            viewModel.dispatch(.searchSatellites(searchText, category: context.category))
        }
        .onDisappear {
            // Clear the search text across different satellite lists
            viewModel.dispatch(.searchSatellites("", category: context.category))
        }
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
                satCat: try! SatCat.with(noradCatID: Int($0.noradIndex)),
                ucsSat: try! UCSSat.with(noradCatID: Int($0.noradIndex))
            )
        }
        .reduce(into: Map<UInt, SatelliteInfo>(), { $0[$1.noradIndex] = $1 })

        SatelliteListView(
            viewModel: .mock(
                state: SatelliteListViewState(
                    satelliteInfo: [.brightest100: .loaded(brightest100)]
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
