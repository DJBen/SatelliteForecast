import Combine
//
//  SatelliteListView.swift
//  SatelliteKitTests
//
//  Created by Ben Lu on 6/5/21.
//

import BTree
import SwiftUI
@preconcurrency import SatelliteKit
import SatelliteForecast
import SatelliteCatalog
import StarryNight

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
    public let starManager: AppStarCatalog
    public let julianDateProvider: () -> Double

    public init(
        category: SatelliteCategory,
        julianDateRange: ClosedRange<Double>,
        observer: LatLonAlt?,
        starManager: AppStarCatalog,
        julianDateProvider: @escaping () -> Double
    ) {
        self.category = category
        self.julianDateRange = julianDateRange
        self.observer = observer
        self.starManager = starManager
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
    @State var viewModel: SatelliteListModel
    let context: SatelliteListViewContext
    let allPassesViewFactory: ViewFactory<AllPassesViewContext, AllPassesView>

    @StateObject var textObserver = TextFieldObserver(delay: 0.5)

    public init(
        viewModel: SatelliteListModel,
        context: SatelliteListViewContext,
        allPassesViewFactory: ViewFactory<AllPassesViewContext, AllPassesView>
    ) {
        self.viewModel = viewModel
        self.context = context
        self.allPassesViewFactory = allPassesViewFactory
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
                Text("The satellites are not loaded.", bundle: .module)
            case .loading:
                ProgressView {
                    Text("Loading...", bundle: .module)
                }
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
                .listRowBackground(AppTheme.surface)
                .listRowSeparatorTint(AppTheme.border)
            }
        }
        .navigationDestination(for: SatelliteListSelectedSatellite.self) { satellite in
            satelliteDestination(satellite, in: satellites)
        }
        .listStyle(.insetGrouped)
    }

    // Navigation transitions can render a destination after the model starts reloading.
    // Resolve against the same immutable catalog snapshot that supplied the tapped row.
    func satelliteDestination(
        _ satellite: SatelliteListSelectedSatellite,
        in satellites: Map<UInt, SatelliteInfo>
    ) -> some View {
        LazyView {
            if let satelliteInfo = satellites[satellite.noradIndex] {
                allPassesViewFactory.view(
                    AllPassesViewContext(
                        satelliteInfo: satelliteInfo,
                        julianDateRange: context.julianDateRange,
                        observer: context.observer,
                        starManager: context.starManager,
                        julianDateProvider: context.julianDateProvider
                    )
                )
            } else {
                Text("The satellite is no longer available.", bundle: .module)
            }
        }
    }

    private func failureView(_ error: Error) -> some View {
        VStack(spacing: 16) {
            Text(error.localizedDescription)

            Button(
                "Retry",
                action: {
                    viewModel.send(
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
        .task { if !SnapshotEnvironment.isEnabled { viewModel.load(context.category) } }
        .onDisappear { viewModel.cancel() }
        .modifier(AppSurface())
        .navigationTitle(Text("Satellites", bundle: .module))
        .searchable(
            text: $textObserver.searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: Text("Filter by name, ID, country, year...", bundle: .module)
        )
        .onChange(of: textObserver.debouncedText) { _, searchText in
            viewModel.send(.searchSatellites(searchText, category: context.category))
        }
        .onDisappear {
            // Clear the search text across different satellite lists
            viewModel.send(.searchSatellites("", category: context.category))
        }
    }
}
