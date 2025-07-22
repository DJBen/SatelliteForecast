//
//  SatelliteOverviewView.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/24/21.
//

import SatelliteForecast
@preconcurrency import SatelliteKit
import SwiftUI
@preconcurrency import SwiftRex
@preconcurrency import CombineRex
@preconcurrency import CombineRextensions
import CoreLocation

public enum SatelliteOverviewViewAction {
    case navigate(
        NavigationPath
    )
    
    case onAppear(
        julianDateRange: ClosedRange<Double>,
        observer: LatLonAlt?
    )

    case selectSatellite(
        specialSatellite: SpecialSatellite,
        julianDateRange: ClosedRange<Double>,
        observer: LatLonAlt?
    )
    
    case deeplinkToLocationSelection
    case showLocationSettings
}

public struct NextPass: Equatable {
    let nextVisiblePass: Pass?
    let nextProminentPass: Pass?
    
    public init(nextVisiblePass: Pass?, nextProminentPass: Pass?) {
        self.nextVisiblePass = nextVisiblePass
        self.nextProminentPass = nextProminentPass
    }
}

public struct SatelliteOverviewViewState: Equatable {
    public var navigationState: NavigationState
    public var observer: LatLonAlt?
    public var julianDateOffset: Double = 0
    public var issNextPass: Loadable<NextPass, Error> = .notLoaded
    public var tianheNextPass: Loadable<NextPass, Error> = .notLoaded
    public var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    public var isMissingLocation: Bool {
        if observer == nil {
            switch authorizationStatus {
            case .notDetermined, .restricted, .denied:
                return true
            default:
                return false
            }
        }
        return false
    }
    
    public init(
        navigationState: NavigationState = .init(),
        observer: LatLonAlt? = nil,
        julianDateOffset: Double = 0,
        issNextPass: Loadable<NextPass, Error> = .loading,
        tianheNextPass: Loadable<NextPass, Error> = .loading,
        authorizationStatus: CLAuthorizationStatus = .notDetermined
    ) {
        self.navigationState = navigationState
        self.observer = observer
        self.julianDateOffset = julianDateOffset
        self.issNextPass = issNextPass
        self.tianheNextPass = tianheNextPass
        self.authorizationStatus = authorizationStatus
    }
}

public protocol SatelliteOverviewView: View {}

public struct SatelliteOverviewViewContext {
    public let julianDateProvider: () -> Double

    public init(julianDateProvider: @escaping () -> Double) {
        self.julianDateProvider = julianDateProvider
    }
}

public struct SatelliteOverviewViewImpl: SatelliteOverviewView {
    @ObservedObject var viewModel: ObservableViewModel<SatelliteOverviewViewAction, SatelliteOverviewViewState>
    @State var currentDate: Date = Date()
    @State private var timer: Timer?
    @State private var scrollOffset: CGFloat = 0
    let context: SatelliteOverviewViewContext
    let singleSatelliteWrappingViewProducer: ViewProducer<SingleSatelliteWrappingViewContext, SingleSatelliteWrappingView>

    public init(
        viewModel: ObservableViewModel<SatelliteOverviewViewAction, SatelliteOverviewViewState>,
        context: SatelliteOverviewViewContext,
        singleSatelliteWrappingViewProducer: ViewProducer<SingleSatelliteWrappingViewContext, SingleSatelliteWrappingView>
    ) {
        self.viewModel = viewModel
        self.context = context
        self.singleSatelliteWrappingViewProducer = singleSatelliteWrappingViewProducer
    }

    public var body: some View {
        NavigationStack(
            path: Binding<NavigationPath>(
                get: {
                    viewModel.state.navigationState.passPredictionNavigationPath
                }, set: { navigationPath in
                    viewModel.dispatch(.navigate(navigationPath))
                }
            )
        ) {
            VStack {
                ScrollView {
                    LazyVStack(
                        alignment: .leading,
                        spacing: 24,
                        pinnedViews: []
                    ) {
                        Section {
                            ForEach(
                                [
                                    SatelliteCategory.iss,
                                    SatelliteCategory.tianhe
                                ],
                                id: \.self
                            ) { satellite in
                                NavigationLink(value: SpecialSatellite(satellite)) {
                                    SatelliteOverviewCell(
                                        satellite: satellite,
                                        nextPassLoadingState: satellite == .iss ? viewModel.state.issNextPass : viewModel.state.tianheNextPass,
                                        currentDate: currentDate,
                                        julianDateOffset: viewModel.state.julianDateOffset,
                                        isMissingLocation: viewModel.state.isMissingLocation,
                                        scrollOffset: scrollOffset
                                    )
                                }
                                .id(satellite.rawValue)
                            }
                        }
                    }
                }
                .navigationBarTitle(
                    Text("Overview", bundle: .module),
                    displayMode: .inline
                )
                .navigationBarHidden(true)
                .navigationDestination(for: SpecialSatellite.self) { specialSatellite in
                    LazyView {
                        singleSatelliteWrappingViewProducer.view(
                            SingleSatelliteWrappingViewContext(
                                selectedNoradIndex: specialSatellite.rawValue,
                                julianDateRange: JulianDateUtil.createJulianDateRange(now: context.julianDateProvider() + viewModel.state.julianDateOffset),
                                observer: viewModel.state.observer,
                                julianDateProvider: context.julianDateProvider
                            )
                        )
                    }
                }
            }
            .tint(Color(uiColor: .label))
            if viewModel.state.isMissingLocation {
                HStack {
                    Image(systemName: "location.slash")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.red, Color(uiColor: .label))
                        .font(.headline)
                    Text("Location needed to calculate satellite passes. Your experience may be degraded.", bundle: .module)
                }
                .font(.footnote)
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
                .padding(.vertical, 4)
            }
        }
        .onAppear {
            viewModel.dispatch(
                .onAppear(
                    julianDateRange: JulianDateUtil.createJulianDateRange(now: context.julianDateProvider() + viewModel.state.julianDateOffset),
                    observer: viewModel.state.observer
                )
            )
            
            // Invalidate existing timer if any
            timer?.invalidate()
            
            // Create new timer to update currentDate every second
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                currentDate = Date()
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#if DEBUG
struct SatelliteOverviewView_Previews: PreviewProvider {
    static var previews: some View {
        SatelliteOverviewViewImpl(
            viewModel: .mock(
                state: SatelliteOverviewViewState()
            ),
            context: SatelliteOverviewViewContext(
                julianDateProvider: { Date().julianDate }
            ),
            singleSatelliteWrappingViewProducer: .crash
        )
    }
}
#endif
