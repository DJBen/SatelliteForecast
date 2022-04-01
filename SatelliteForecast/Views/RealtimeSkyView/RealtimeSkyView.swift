//
//  RealtimeSkyView.swift
//  RealtimeSkyView
//
//  Created by Ben Lu on 3/2/22.
//

import BTree
import CombineRex
import CombineRextensions
import SatelliteForecastCore
import SatelliteKit
import SwiftRex
import SwiftUI

enum RealtimeSkyViewAction {
    case propagateCurrentEphemerides([SatelliteInfo], observer: LatLonAlt, julianDate: Double)
    case setRealtimeSkyViewActive(Bool)
}

extension RealtimeSkyViewAction: Equatable {}

enum RealtimeSkyViewOutput {
    case propagatedCurrentEphemerides(
        results: BTree<Double, RealtimePropagationResult>,
        satellites: [SatelliteInfo],
        partialErrors: [Error],
        observer: LatLonAlt,
        julianDate: Double
    )

    case failedToPropagateCurrentEphemerides(
        error: Error,
        observer: LatLonAlt,
        julianDate: Double
    )
}

struct RealtimeSkyViewResources {
    /// The propagation results containing the satellite snapshot ordered by the time when next check should take place.
    var results: BTree<Double, RealtimePropagationResult> = .init()
    var displayResults: [RealtimePropagationResult] = []
    var isRealtimeSkyViewActive: Bool = false
    var isPropagatingEphemerides: Bool = false
}

extension RealtimeSkyViewResources: Equatable {}

struct RealtimeSkyViewState {
    var resources: RealtimeSkyViewResources = .init()
    var satellites: Loadable<[SatelliteInfo], ElementsLoaderError> = .notLoaded
    var observer: LatLonAlt?
    var julianDateOffset: Double = 0
}

extension RealtimeSkyViewState: Equatable {}

struct RealtimeSkyViewContext {
    let basicChartConfigs: BasicChartConfigs
    let backgroundSkyConfigs: BackgroundSkyConfigs
    let satelliteMagToRadiusFunction: BackgroundSkyConfigs.StarMagToDisplayRadiusMappingFunction
}

/// A protocol of real time sky view. Preview code can mock the implementation as a depednency.
protocol RealtimeSkyView: View {}

struct RealtimeSkyViewImpl: RealtimeSkyView {
    @ObservedObject var viewModel: ObservableViewModel<RealtimeSkyViewAction, RealtimeSkyViewState>
    let context: RealtimeSkyViewContext
    let backgroundSkyViewProducer: ViewProducer<BackgroundSkyViewContext, BackgroundSkyView>

    let refreshTimer = Timer.publish(
        every: 0.5,
        on: .main,
        in: .common
    )
    .autoconnect()
    .map(\.julianDate)

    @State var julianDate: Double?
    @State var rotateLoadingCircle = false

    @ViewBuilder private func locationView<Content: View, NoLocationContent: View>(
        @ViewBuilder contentBuilder: (LatLonAlt) -> Content,
        @ViewBuilder noLocationContentBuilder: () -> NoLocationContent
    ) -> some View {
        if let observer = viewModel.state.observer {
            contentBuilder(observer)
        } else {
            noLocationContentBuilder()
        }
    }

    private var visiblePropagationResults: [RealtimePropagationResult] {
        viewModel.state.resources.displayResults
        .filter { ($0.snapshot.visualMagnitude ?? .infinity) <= 5.5 }
        .sorted { result1, result2 in
            if let mag1 = result1.snapshot.visualMagnitude, let mag2 = result2.snapshot.visualMagnitude {
                return mag1 < mag2
            } else if let _ = result1.snapshot.visualMagnitude {
                return true
            } else if let _ = result2.snapshot.visualMagnitude {
                return false
            } else {
                return result1.snapshot.position.dist < result2.snapshot.position.dist
            }
        }
    }

    /// The propagation results that should have labels shown
    private var showLabelPropagationResults: [RealtimePropagationResult] {
        let visiblePropagationResults = visiblePropagationResults
        return viewModel.state.resources.displayResults.filter { result in
            result.snapshot.position.elev > 15 && !visiblePropagationResults.contains(result)
        }
    }

    @ViewBuilder private var satellitePlotLabels: some View {
        if viewModel.state.resources.isRealtimeSkyViewActive {
            GeometryReader { geometry in
                let rect = geometry.frame(in: .local)

                ZStack(alignment: .center) {
                    ForEach(
                        showLabelPropagationResults,
                        id: \.self
                    ) { result in
                        Text(
                            Self.satelliteLabelInGraph(result.satelliteInfo)
                        )
                        .font(.system(size: 8, weight: .regular, design: .default))
                        .foregroundColor(.gray)
                        .offset(y: 8)
                        .frame(alignment: .leading)
                        .position(
                            SkyChart.point(
                                at: result.snapshot.position,
                                rect: rect
                            )
                        )
                    }

                    ForEach(
                        visiblePropagationResults,
                        id: \.self
                    ) { result in
                        Text(
                            Self.satelliteLabelInGraph(result.satelliteInfo)
                        )
                        .font(.system(size: 9, weight: .regular, design: .default))
                        .foregroundColor(.orange)
                        .offset(y: 12)
                        .frame(alignment: .leading)
                        .position(
                            SkyChart.point(
                                at: result.snapshot.position,
                                rect: rect
                            )
                        )
                    }
                }
            }
        } else {
            Color.clear
        }
    }

    private func paths(from results: [RealtimePropagationResult], rect: CGRect) -> Path {
        Path { path in
            for result in results {
                let point = SkyChart.point(
                    at: result.snapshot.position,
                    rect: rect
                )

                path.addArc(
                    center: CGPoint(x: point.x, y: point.y),
                    radius: context.satelliteMagToRadiusFunction.apply(result.snapshot.visualMagnitude ?? 5.5),
                    startAngle: Angle(degrees: 0),
                    endAngle: Angle(degrees: 360),
                    clockwise: false
                )
                path.closeSubpath()
            }
        }
    }

    @ViewBuilder private var satellitePlot: some View {
        if viewModel.state.resources.isRealtimeSkyViewActive {
            GeometryReader { geometry in
                let rect = geometry.frame(in: .local)

                paths(
                    from: viewModel.state.resources.displayResults,
                    rect: rect
                )
                .fill(.blue)

                paths(
                    from: visiblePropagationResults,
                    rect: rect
                )
                .fill(.orange)

                Path { path in
                    for result in visiblePropagationResults {
                        let point = SkyChart.point(
                            at: result.snapshot.position,
                            rect: rect
                        )

                        path.move(to: CGPoint(x: point.x - 4, y: point.y))
                        path.addLine(to: CGPoint(x: point.x - 8, y: point.y))
                        path.move(to: CGPoint(x: point.x + 4, y: point.y))
                        path.addLine(to: CGPoint(x: point.x + 8, y: point.y))
                        path.move(to: CGPoint(x: point.x, y: point.y - 4))
                        path.addLine(to: CGPoint(x: point.x, y: point.y - 8))
                        path.move(to: CGPoint(x: point.x, y: point.y + 4))
                        path.addLine(to: CGPoint(x: point.x, y: point.y + 8))
                    }
                }
                .stroke(.gray, lineWidth: 1)
            }
        } else {
            Color.clear
        }
    }

    @ViewBuilder private func backgroundSkyView(observer: LatLonAlt) -> some View {
        backgroundSkyViewProducer.view(
            BackgroundSkyViewContext(
                observer: observer,
                basicChartConfigs: context.basicChartConfigs,
                configs: context.backgroundSkyConfigs,
                quality: .full
            )
        )
        .environment(
            \.backgroundSkyJulianDateKey,
             julianDate.map { $0.roundJulianDate(.toMins(1)) }
        )
        .overlay {
            satellitePlot
        }
        .overlay(
            satellitePlotLabels
        )
        .onReceive(refreshTimer) { timerJulianDate in
            self.julianDate = timerJulianDate + viewModel.state.julianDateOffset

            guard viewModel.state.resources.isRealtimeSkyViewActive else {
                return
            }
            if viewModel.state.resources.isPropagatingEphemerides {
                return
            }

            guard case .loaded(let satellites) = viewModel.state.satellites else {
                return
            }

            viewModel.dispatch(
                .propagateCurrentEphemerides(
                    satellites,
                    observer: observer,
                    julianDate: julianDate!
                )
            )
        }
    }

    @ViewBuilder private var satelliteLoadingView: some View {
        VStack {
            ProgressView {
                Text(
                    Self.SatelliteList.loadingText
                )
                .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder private var satelliteList: some View {
        switch viewModel.state.satellites {
        case .notLoaded:
            Color.clear
        case .loading:
            satelliteLoadingView
        case .failed(_):
            Color.clear
        case .loaded(_):
            if visiblePropagationResults.isEmpty {
                Text(
                    Self.SatelliteList.emptyText
                )
                .foregroundColor(.secondary)
            } else {
                List {
                    ForEach(visiblePropagationResults, id: \.self) { result in
                        RealtimeSkySatelliteCell(
                            isFocused: .constant(false),
                            satelliteInfo: result.satelliteInfo,
                            snapshot: result.snapshot
                        )
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    var body: some View {
        NavigationView {
            locationView { observer in
                GeometryReader { geometry in
                    let rect = geometry.frame(in: .local)
                    VStack(spacing: 16) {
                        backgroundSkyView(
                            observer: observer
                        )
                        .frame(
                            width: min(rect.width, rect.height),
                            height: min(rect.width, rect.height)
                        )

                        satelliteList.padding(.top, 24)
                    }
                    .padding(.top, 16)
                }
            } noLocationContentBuilder: {
                Text(verbatim: "Location not available")
            }
            .navigationTitle(Self.Navigation.title)
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
        .onAppear {
            viewModel.dispatch(.setRealtimeSkyViewActive(true))
        }
        .onDisappear {
            viewModel.dispatch(.setRealtimeSkyViewActive(false))
        }
    }
}

extension RealtimeSkyViewImpl {
    enum Navigation {
        static var title: String {
            NSLocalizedString(
                "realtimeSkyView.navigation.title",
                tableName: nil,
                bundle: .main,
                value: "Sky now",
                comment: "The navigation title of the realtime sky view"
            )
        }
    }

    enum SatelliteList {
        static var loadingText: String {
            NSLocalizedString(
                "realtimeSkyView.satelliteList.loadingText",
                tableName: nil,
                bundle: .main,
                value: "Searching for satellites...",
                comment: "The loading text for the satellite list"
            )
        }

        static var emptyText: String {
            NSLocalizedString(
                "realtimeSkyView.satelliteList.emptyText",
                tableName: nil,
                bundle: .main,
                value: "No satellite currently visible",
                comment: "The empty text for the satellite list"
            )
        }
    }

    static func satelliteLabelInGraph(_ satelliteInfo: SatelliteInfo) -> String {
        satelliteInfo.ucsSat?.officialName ?? satelliteInfo.satCat?.name ?? satelliteInfo.elements.commonName
    }
}

#if DEBUG

struct RealtimeSkyView_Previews: PreviewProvider {
    static var previews: some View {
        RealtimeSkyViewImpl(
            viewModel: .mock(
                state: .init()
            ),
            context: RealtimeSkyViewContext(
                basicChartConfigs: .init(),
                backgroundSkyConfigs: .init(),
                satelliteMagToRadiusFunction: .init()
            ),
            backgroundSkyViewProducer: .pure(
                BackgroundSkyView(
                    viewModel: .mock(
                        state: BackgroundSkyViewState()
                    ),
                    context: BackgroundSkyViewContext(
                        observer: LatLonAlt(lat: 0, lon: 0, alt: 0),
                        basicChartConfigs: .init(),
                        configs: .init(),
                        quality: .full
                    )
                )
            )
        )
        .environment(\.backgroundSkyJulianDateKey, 0)
    }
}

#endif
