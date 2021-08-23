//
//  SingleSatelliteWrappingView.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 7/9/21.
//

import SwiftUI
import CombineRex
import CombineRextensions
import SatelliteForecastCore

enum SingleSatelliteWrappingViewAction {
    case loadSingleSatellite
    case calculateSingleSatellitePass(noradIndex: Int)
}

struct SingleSatelliteWrappingViewState: Equatable {
    var satellite: Result<SatelliteInfo, SatelliteLoaderError>?
    var noradIndex: Int

    static func project(state: AppState) -> SingleSatelliteWrappingViewState? {
        guard let noradIndex = state.navigationState.selectedSatelliteNoradIndex else {
            return nil
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

        return SingleSatelliteWrappingViewState(
            satellite: satellite,
            noradIndex: noradIndex
        )
    }
}

struct SingleSatelliteWrappingView: View {
    @ObservedObject var viewModel: ObservableViewModel<SingleSatelliteWrappingViewAction, SingleSatelliteWrappingViewState?>
    let allPassesViewProducer: ViewProducer<AllPassesViewContext, AllPassesView>

    @ViewBuilder func satelliteContent<Content: View, FailedContent: View>(
        @ViewBuilder contentBuilder: (SatelliteInfo) -> Content,
        @ViewBuilder failedContentBuilder: (Int, SatelliteLoaderError) -> FailedContent
    ) -> some View {
        if let state = viewModel.state {
            Group {
                switch state.satellite {
                case .none:
                    ProgressView("Loading...")
                case let .success(satellite):
                    contentBuilder(satellite)
                case let .failure(error):
                    failedContentBuilder(state.noradIndex, error)
                }
            }
            .onAppear {
                if case .success(_) = state.satellite {
                    viewModel.dispatch(.calculateSingleSatellitePass(noradIndex: state.noradIndex))
                }
            }
            .onChange(of: state.satellite) { newValue in
                if newValue == .none {
                    return
                }
                
                viewModel.dispatch(.calculateSingleSatellitePass(noradIndex: state.noradIndex))
            }
        }
    }

    var body: some View {
        satelliteContent { satellite in
            allPassesViewProducer.view(AllPassesViewContext())
        }
        failedContentBuilder: { noradIndex, error in
            VStack(spacing: 16) {
                Text(error.localizedDescription)

                Button(
                    "Retry",
                    action: { viewModel.dispatch(.loadSingleSatellite) }
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
                .asObservableViewModel(initialState: nil, emitsValue: .whenDifferent),
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
            viewModel: .mock(state: nil),
            allPassesViewProducer: .crash
        )
    }
}
#endif
