import SatelliteForecast
@preconcurrency import SatelliteKit
import SwiftUI
@preconcurrency import SwiftRex
@preconcurrency import CombineRex
@preconcurrency import CombineRextensions
import CoreLocation

public enum SatelliteCategoryViewAction {
    case navigate(
        NavigationPath
    )

    case loadCategory(
        SatelliteCategory,
        julianDateRange: ClosedRange<Double>,
        observer: LatLonAlt?
    )
}

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
    public let julianDateProvider: () -> Double

    public init(julianDateProvider: @escaping () -> Double) {
        self.julianDateProvider = julianDateProvider
    }
}

public struct SatelliteCategoryViewImpl: SatelliteCategoryView {
    @ObservedObject var viewModel: ObservableViewModel<SatelliteCategoryViewAction, SatelliteCategoryViewState>
    let context: SatelliteCategoryViewContext
    let listViewProducer: ViewProducer<SatelliteListViewContext, SatelliteListView>

    public init(
        viewModel: ObservableViewModel<SatelliteCategoryViewAction, SatelliteCategoryViewState>,
        context: SatelliteCategoryViewContext,
        listViewProducer: ViewProducer<SatelliteListViewContext, SatelliteListView>,
    ) {
        self.viewModel = viewModel
        self.context = context
        self.listViewProducer = listViewProducer
    }

    public var body: some View {
        NavigationStack(
            path: Binding<NavigationPath>(
                get: {
                    viewModel.state.navigationPath
                }, set: { navigationPath in
                    viewModel.dispatch(.navigate(navigationPath))
                }
            )
        ) {
            ScrollView {
                LazyVStack(
                    alignment: .leading,
                    spacing: 10,
                    pinnedViews: []
                ) {
                    Section {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible()),
                            ],
                            alignment: .leading,
                            spacing: 10
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
                .padding()
            }
            .navigationBarTitle("Satellite Categories", displayMode: .inline)
            .navigationBarHidden(true)
            .navigationDestination(for: SatelliteCategory.self) { category in
                LazyView {
                    listViewProducer.view(
                        SatelliteListViewContext(
                            category: category,
                            julianDateRange: JulianDateUtil.createJulianDateRange(now: context.julianDateProvider() + viewModel.state.julianDateOffset),
                            observer: viewModel.state.observer,
                            julianDateProvider: context.julianDateProvider
                        )
                    )
                    .onAppear {
                        viewModel.dispatch(
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
        .tint(Color(uiColor: .label))
    }
}

#if DEBUG
struct SatelliteCategoryView_Previews: PreviewProvider {
    static var previews: some View {
        SatelliteCategoryViewImpl(
            viewModel: .mock(
                state: SatelliteCategoryViewState()
            ),
            context: SatelliteCategoryViewContext(
                julianDateProvider: { Date().julianDate }
            ),
            listViewProducer: .crash
        )
    }
}
#endif
