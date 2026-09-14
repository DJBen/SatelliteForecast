//
//  SatelliteOverviewView.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/24/21.
//

import SatelliteForecast
@preconcurrency import SatelliteKit
import SwiftUI
import CoreLocation
import StarryNight

public struct NextPass: Equatable, Sendable {
    let nextVisiblePass: Pass?
    let nextProminentPass: Pass?
    
    public init(nextVisiblePass: Pass?, nextProminentPass: Pass?) {
        self.nextVisiblePass = nextVisiblePass
        self.nextProminentPass = nextProminentPass
    }
}

public protocol SatelliteOverviewView: View {}

public struct SatelliteOverviewViewContext {
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

public struct SatelliteOverviewViewImpl: SatelliteOverviewView {
    let model: ForecastModel
    let input: ForecastInput
    @Binding private var navigationPath: NavigationPath
    let context: SatelliteOverviewViewContext
    let singleSatelliteWrappingViewFactory: (SingleSatelliteWrappingViewContext) -> SingleSatelliteWrappingView

    public init(
        model: ForecastModel,
        input: ForecastInput,
        navigationPath: Binding<NavigationPath>,
        context: SatelliteOverviewViewContext,
        singleSatelliteWrappingViewFactory: @escaping (SingleSatelliteWrappingViewContext) -> SingleSatelliteWrappingView
    ) {
        self.model = model
        self.input = input
        self._navigationPath = navigationPath
        self.context = context
        self.singleSatelliteWrappingViewFactory = singleSatelliteWrappingViewFactory
    }

    public var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack {
                ScrollView {
                    LazyVStack(
                        alignment: .leading,
                        spacing: 20,
                        pinnedViews: []
                    ) {
                        Text("Pass forecast", bundle: .module)
                            .font(.largeTitle.bold())
                            .foregroundStyle(.primary)
                            .padding(.top, 8)
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
                                        nextPassLoadingState: satellite == .iss ? model.issNextPass : model.tianheNextPass,
                                        currentDate: model.currentDate,
                                        julianDateOffset: input.julianDateOffset,
                                        isMissingLocation: input.isMissingLocation,
                                    )
                                }
                                .id(satellite.rawValue)
                                .animation(.easeInOut(duration: 0.3), value: model.currentDate)
                            }
                        }
                    }
                }
                .refreshable { await model.refresh(input) }
                .padding(.horizontal, 16)
                .modifier(AppSurface())
                .navigationBarTitle(
                    Text("Overview", bundle: .module),
                    displayMode: .inline
                )
                .navigationBarHidden(true)
                .navigationDestination(for: SpecialSatellite.self) { specialSatellite in
                    LazyView {
                        singleSatelliteWrappingViewFactory(
                            SingleSatelliteWrappingViewContext(
                                selectedNoradIndex: specialSatellite.rawValue,
                                julianDateRange: JulianDateUtil.createJulianDateRange(now: context.julianDateProvider() + input.julianDateOffset),
                                observer: input.observer,
                                starManager: context.starManager,
                                julianDateProvider: context.julianDateProvider
                            )
                        )
                    }
                }
            }
            .tint(AppTheme.accent)
            
            if input.isMissingLocation {
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
        .task(id: input) {
            guard !SnapshotEnvironment.isEnabled else { return }
            await model.run(input)
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
            model: ForecastModel(client: .init(load: { _, _ in [] })),
            input: .init(),
            navigationPath: .constant(NavigationPath()),
            context: SatelliteOverviewViewContext(
                starManager: StarManagerMock(),
                julianDateProvider: {
                    Date().julianDate
                }
            ),
            singleSatelliteWrappingViewFactory: { _ in fatalError("Preview destination") }
        )
    }
}
#endif
