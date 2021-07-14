//
//  SatelliteOverviewView.swift
//  SatelliteForcast
//
//  Created by Ben Lu on 6/24/21.
//

import SwiftUI
import SwiftRex
import CombineRex
import CombineRextensions

enum SatelliteOverviewViewAction {
    case selectSpecialSatellite(noradIndex: Int?)
    case selectCategory(SatelliteCategory?)
}

struct SatelliteOverviewViewState: Equatable {
    let navigationState: NavigationState

    static func project(state: AppState) -> SatelliteOverviewViewState {
        SatelliteOverviewViewState(navigationState: state.navigationState)
    }

    static var initial: SatelliteOverviewViewState {
        SatelliteOverviewViewState(navigationState: .overview)
    }
}

fileprivate extension SatelliteOverviewItem {
    var navigationIndexPath: NavigationIndexPath {
        switch self {
        case let .specialSatellites(satellite):
            return NavigationIndexPath(category: nil, noradIndex: satellite.rawValue)
        case let .category(category):
            return NavigationIndexPath(category: category)
        case .management(_):
            fatalError("Unimplemented")
        }
    }
}

struct SatelliteOverviewView: View {
    @ObservedObject var viewModel: ObservableViewModel<SatelliteOverviewViewAction, SatelliteOverviewViewState>
    let listViewProducer: ViewProducer<Void, SatelliteListView>
    let singleSatelliteWrappingViewProducer: ViewProducer<Void, SingleSatelliteWrappingView>

    let sections: [SatelliteOverviewSection] = [
        .satellitesOfSpecialInterest([
            .specialSatellites(.iss),
            .specialSatellites(.tianhe)
        ]),
        .categories([
            .category(.brightest100),
            .category(.active),
            .category(.last30DayLaunches)
        ])
    ]

    private func destination(for item: SatelliteOverviewItem) -> some View {
        switch item {
        case .specialSatellites(_):
            return AnyView(singleSatelliteWrappingViewProducer.view())
        case .category(_):
            return AnyView(listViewProducer.view())
        case .management(_):
            fatalError("Unimplemented")
        }
    }

    private struct SpecialSatelliteNavTag: Equatable, Hashable {
        let category: SatelliteCategory?
        let noradIndex: Int?

        init(_ navigationIndexPath: NavigationIndexPath) {
            category = navigationIndexPath.category
            noradIndex = navigationIndexPath.noradIndex
        }
    }

    private struct CategoryNavTag: Equatable, Hashable {
        let category: SatelliteCategory?

        init(_ navigationIndexPath: NavigationIndexPath) {
            category = navigationIndexPath.category
        }
    }

    private func navigationLink<Label: View>(
        for item: SatelliteOverviewItem,
        @ViewBuilder label: () -> Label
    ) -> some View {
        switch item {
        case .specialSatellites:
            return AnyView(NavigationLink(
                destination: destination(for: item),
                tag: SpecialSatelliteNavTag(item.navigationIndexPath),
                selection: Binding<SpecialSatelliteNavTag?>(
                    get: { SpecialSatelliteNavTag(viewModel.state.navigationState.indexPath) },
                    set: { viewModel.dispatch(.selectSpecialSatellite(noradIndex: $0?.noradIndex)) }
                ),
                label: label
            ))
        case .category:
            return AnyView(NavigationLink(
                destination: destination(for: item),
                tag: CategoryNavTag(item.navigationIndexPath),
                selection: Binding<CategoryNavTag?>(
                    get: { CategoryNavTag(viewModel.state.navigationState.indexPath) },
                    set: {
                        viewModel.dispatch(.selectCategory($0?.category))
                    }
                ),
                label: label
            ))
        case .management(_):
            fatalError()
        }
    }

    private func sectionView(_ section: SatelliteOverviewSection) -> some View {
        ForEach(section.items, id: \.self) { item in
            navigationLink(for: item) {
                SatelliteOverviewCell(model: SatelliteOverviewCellModel(item: item))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .id(item)
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(
                    alignment: .leading,
                    spacing: 10,
                    pinnedViews: .sectionHeaders
                ) {
                    ForEach(sections, id: \.self) { section in
                        Section(
                            header: Text(LocalizedStrings.SatelliteOverviewView.sectionTitle(section))
                                .font(.headline.lowercaseSmallCaps().weight(.semibold))
                                .foregroundColor(Color(UIColor.secondaryLabel))
                        ) {
                            sectionView(section)
                        }
                    }
                }
                .padding()
            }
            .navigationBarTitle("Overview", displayMode: .inline)
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

extension ViewProducer where Context == Void, ProducedView == SatelliteOverviewView {
    static func satelliteOverview<S: StoreType>(viewModel: S) -> ViewProducer where S.ActionType == AppAction, S.StateType == AppState {
        ViewProducer<Context, ProducedView> { context in
            SatelliteOverviewView(
                viewModel: viewModel.projection(
                    action: AppAction.satelliteOverview,
                    state: SatelliteOverviewViewState.project(state:)
                )
                .asObservableViewModel(initialState: .initial),
                listViewProducer: ViewProducer<Void, SatelliteListView>
                    .satelliteListView(viewModel: viewModel),
                singleSatelliteWrappingViewProducer: ViewProducer<Void, SingleSatelliteWrappingView>.singleSatelliteWrappingView(viewModel: viewModel)
            )
        }
    }
}

#if DEBUG
struct SatelliteOverviewView_Previews: PreviewProvider {
    static var previews: some View {
        SatelliteOverviewView(
            viewModel: .mock(
                state: SatelliteOverviewViewState(navigationState: .overview)
            ),
            listViewProducer: .crash,
            singleSatelliteWrappingViewProducer: .crash
        )
    }
}
#endif
