import SatelliteForecast
@preconcurrency import SatelliteKit
import SwiftUI
import CoreLocation
import StarryNight

public struct SatelliteCategoryViewState: Equatable {
    public var navigationPath: NavigationPath
    public var observer: LatLonAlt?
    public var julianDateOffset: Double = 0

    public init(
        navigationPath: NavigationPath = .init(),
        observer: LatLonAlt? = nil,
        julianDateOffset: Double = 0
    ) {
        self.navigationPath = navigationPath
        self.observer = observer
        self.julianDateOffset = julianDateOffset
    }
}

public protocol SatelliteCategoryView: View {}

public struct SatelliteCategoryViewContext {
    public let starManager: AppStarCatalog
    public let julianDateProvider: () -> Double

    public init(
        starManager: AppStarCatalog,
        julianDateProvider: @escaping () -> Double
    ) {
        self.starManager = starManager
        self.julianDateProvider = julianDateProvider
    }
}

public struct SatelliteCategoryViewImpl: SatelliteCategoryView {
    @State var viewModel: SatelliteCategoryModel
    @State private var navigationPath: NavigationPath
    let context: SatelliteCategoryViewContext
    let listViewFactory: ViewFactory<SatelliteListViewContext, SatelliteListView>
    /// Optional content shown above the categories, such as the station cards.
    let header: AnyView?
    /// Destination for `SpecialSatellite` links in the header. Registered on the stack root,
    /// because a destination declared inside the lazy content is not reliably found.
    let stationDestination: ((SpecialSatellite) -> AnyView)?

    public init(
        viewModel: SatelliteCategoryModel,
        context: SatelliteCategoryViewContext,
        listViewFactory: ViewFactory<SatelliteListViewContext, SatelliteListView>,
        header: AnyView? = nil,
        stationDestination: ((SpecialSatellite) -> AnyView)? = nil
    ) {
        self.viewModel = viewModel
        self._navigationPath = State(initialValue: viewModel.state.navigationPath)
        self.context = context
        self.listViewFactory = listViewFactory
        self.header = header
        self.stationDestination = stationDestination
    }

    public var body: some View {
        NavigationStack(path: $navigationPath) {
            GeometryReader { geometry in
                ScrollView {
                    LazyVStack(
                        alignment: .leading,
                        spacing: 10,
                        pinnedViews: []
                    ) {
                        Text("Satellites", bundle: .module)
                            .font(.largeTitle.bold())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)
                        if let header { header.padding(.bottom, 10) }
                        Section {
                            LazyVStack(
                                alignment: .leading,
                                spacing: 20,
                                pinnedViews: []
                            ) {
                                ForEach(
                                    [
                                        SatelliteCategory.brightest100,
                                        SatelliteCategory.active,
                                        SatelliteCategory.last30DayLaunches
                                    ],
                                    id: \.self
                                ) { category in
                                    NavigationLink(value: category) {
                                        SatelliteCategoryCell(category: category)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .contentMargins(.bottom, geometry.safeAreaInsets.bottom, for: .scrollContent)
                .ignoresSafeArea(.container, edges: .bottom)
                .modifier(AppSurface())
                .navigationBarTitle(
                    Text(
                        "Satellite Categories",
                        bundle: .module
                    ),
                    displayMode: .inline
                )
                .navigationBarHidden(true)
        .analyticsScreen(.categories)
                .navigationDestination(for: SpecialSatellite.self) { station in
                    if let stationDestination { stationDestination(station) }
                }
                .navigationDestination(for: SatelliteCategory.self) { category in
                    LazyView {
                        listViewFactory.view(
                            SatelliteListViewContext(
                                category: category,
                                julianDateRange: JulianDateUtil.createJulianDateRange(now: context.julianDateProvider() + viewModel.state.julianDateOffset),
                                observer: viewModel.state.observer,
                                starManager: context.starManager,
                                julianDateProvider: context.julianDateProvider
                            )
                        )
                        .onAppear {
                            viewModel.send(
                                .loadCategory(
                                    category,
                                    julianDateRange: JulianDateUtil.createJulianDateRange(now: context.julianDateProvider() + viewModel.state.julianDateOffset),
                                    observer: viewModel.state.observer
                                )
                            )
                        }
                    }
                }
            }
        }
        .environment(\.passNavigationPath, $navigationPath)
        .onChange(of: navigationPath) { _, path in
            if viewModel.state.navigationPath != path {
                viewModel.send(.navigate(path))
            }
        }
        .onChange(of: viewModel.state.navigationPath) { _, path in
            if navigationPath != path { navigationPath = path }
        }
        .modifier(CompactHeightLayout())
        .tint(AppTheme.accent)
    }
}
