//
//  SingleSatelliteWrappingView.swift
//  SatelliteForcast
//
//  Created by Ben Lu on 7/9/21.
//

import SwiftUI
import CombineRex
import CombineRextensions
import SatelliteForcastCore

enum SingleSatelliteWrappingViewAction {
    case loadSatelliteList
}

struct SingleSatelliteWrappingViewState: Equatable {
    var satellite: Result<SatelliteInfo, SatelliteLoaderError>?

    static var empty: SingleSatelliteWrappingViewState {
        SingleSatelliteWrappingViewState()
    }

    static func project(state: AppState) -> SingleSatelliteWrappingViewState {
        guard let noradIndex = state.navigationState.selectedSatelliteNoradIndex else {
            return .empty
        }
        let satellite: Result<SatelliteInfo, SatelliteLoaderError>?
        switch state.satelliteLoaderState.info[.brightest100] {
        case .none:
            satellite = nil
        case let .success(satellites):
            satellite = satellites[noradIndex].map { .success($0) }
        case let .failure(error):
            satellite = .failure(error)
        }

        return SingleSatelliteWrappingViewState(satellite: satellite)
    }
}

struct SingleSatelliteWrappingView: View {
    @ObservedObject var viewModel: ObservableViewModel<SingleSatelliteWrappingViewAction, SingleSatelliteWrappingViewState>
    let allPassesViewProducer: ViewProducer<AllPassesViewContext, AllPassesView>

    func satelliteContent<Content: View, FailedContent: View>(
        @ViewBuilder contentBuilder: (SatelliteInfo) -> Content,
        @ViewBuilder failedContentBuilder: (SatelliteLoaderError) -> FailedContent
    ) -> some View {
        switch viewModel.state.satellite {
        case .none:
            return AnyView(ProgressView("Loading..."))
        case let .success(satellite):
            return AnyView(contentBuilder(satellite))
        case let .failure(error):
            return AnyView(failedContentBuilder(error))
        }
    }

    var body: some View {
        satelliteContent { satellite in
            allPassesViewProducer.view(AllPassesViewContext())
        }
        failedContentBuilder: { error in
            VStack(spacing: 16) {
                Text(error.localizedDescription)

                Button(
                    "Retry",
                    action: { viewModel.dispatch(.loadSatelliteList) }
                )
                .font(Font.headline)
                .foregroundColor(Color(UIColor.systemBlue))
            }
        }
    }
}

extension ViewProducer where Context == Void, ProducedView == SingleSatelliteWrappingView {
    static func singleSatelliteWrappingView<S: StoreType>(viewModel: S) -> ViewProducer where S.ActionType == AppAction, S.StateType == AppState {
        ViewProducer<Context, ProducedView> { context in
            SingleSatelliteWrappingView(
                viewModel: viewModel.projection(
                    action: AppAction.singleSatelliteWrappingView,
                    state: SingleSatelliteWrappingViewState.project(state:)
                )
                .asObservableViewModel(initialState: .empty),
                allPassesViewProducer: ViewProducer<AllPassesViewContext, AllPassesView>
                    .allPassesView(viewModel: viewModel)
            )
        }
    }
}

#if DEBUG
struct SingleSatelliteWrappingView_Previews: PreviewProvider {
    static var previews: some View {
        SingleSatelliteWrappingView(
            viewModel: .mock(state: .empty),
            allPassesViewProducer: .crash
        )
    }
}
#endif
