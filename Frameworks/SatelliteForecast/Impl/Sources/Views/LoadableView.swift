//
//  LoadableView.swift
//  TakeABrick
//
//  Created by Ben Lu on 12/24/21.
//

import SatelliteForecast
import SwiftUI

/// A view offers different subview for `Loadable` various states.
struct LoadableView<ContentModel, ContentView, LoadingView, NotLoadedView, FailureView, ErrorType>: View where ContentView: View, LoadingView: View, NotLoadedView: View, FailureView: View {
    let loadableContent: Loadable<ContentModel, ErrorType>
    @ViewBuilder let contentView: (ContentModel) -> ContentView
    @ViewBuilder let loadingView: () -> LoadingView
    @ViewBuilder let notLoadedView: () -> NotLoadedView
    @ViewBuilder let failureView: (ErrorType) -> FailureView

    init(
        loadableContent: Loadable<ContentModel, ErrorType>,
        @ViewBuilder contentView: @escaping (ContentModel) -> ContentView,
        @ViewBuilder loadingView: @escaping () -> LoadingView,
        @ViewBuilder notLoadedView: @escaping () -> NotLoadedView,
        @ViewBuilder failureView: @escaping (ErrorType) -> FailureView
    ) {
        self.loadableContent = loadableContent
        self.contentView = contentView
        self.loadingView = loadingView
        self.notLoadedView = notLoadedView
        self.failureView = failureView
    }
    
    var body: some View {
        switch loadableContent {
        case .notLoaded:
            notLoadedView()
        case .loading:
            loadingView()
        case .loaded(let contentModel):
            contentView(contentModel)
        case .failed(let error):
            failureView(error)
        }
    }
}

extension LoadableView where LoadingView == ProgressView<EmptyView, EmptyView>, NotLoadedView == Color, FailureView == AnyView, ErrorType: LocalizedError {
    init(
        loadableContent: Loadable<ContentModel, ErrorType>,
        @ViewBuilder contentView: @escaping (ContentModel) -> ContentView
    ) {
        self.init(
            loadableContent: loadableContent,
            contentView: contentView,
            loadingView: { ProgressView() },
            notLoadedView: { Color.clear },
            failureView: { error in
                AnyView(
                    VStack {
                        Image(systemName: "xmark")
                        Text(error.localizedDescription)
                    }
                )
            }
        )
    }
}

extension LoadableView where LoadingView == ProgressView<EmptyView, EmptyView>, NotLoadedView == Color, FailureView == Color, ErrorType == Never {
    init(
        loadableContent: Loadable<ContentModel, ErrorType>,
        @ViewBuilder contentView: @escaping (ContentModel) -> ContentView
    ) {
        self.init(
            loadableContent: loadableContent,
            contentView: contentView,
            loadingView: { ProgressView() },
            notLoadedView: { Color.clear },
            failureView: { error in
                Color.clear
            }
        )
    }
}

#if DEBUG

struct LoadableView_Previews: PreviewProvider {
    static var previews: some View {
        LoadableView(
            loadableContent: .loaded("Hello World")
        ) { model in
            Text(model)
        }
        
        LoadableView(
            loadableContent: Loadable<String, Never>.loading
        ) { model in
            Text(model)
        }
    }
}

#endif
