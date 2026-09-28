import Combine
//
//  RealtimeSkyView.swift
//  RealtimeSkyView
//
//  Created by Ben Lu on 3/2/22.
//

import BTree
import SatelliteForecast
@preconcurrency import SatelliteKit
import StarryNight
import SwiftUI
import CoreMotion

public struct RealtimeSkyViewState {
    public var resources: RealtimeSkyViewResources = .init()
    public var satellites: Loadable<[SatelliteInfo], ElementsLoaderError> = .notLoaded
    public var observer: LatLonAlt?
    public var julianDateOffset: Double = 0

    public init(
        resources: RealtimeSkyViewResources = .init(),
        satellites: Loadable<[SatelliteInfo], ElementsLoaderError> = .notLoaded,
        observer: LatLonAlt? = nil,
        julianDateOffset: Double = 0
    ) {
        self.resources = resources
        self.satellites = satellites
        self.observer = observer
        self.julianDateOffset = julianDateOffset
    }
}

extension RealtimeSkyViewState: Equatable {}

public struct RealtimeSkyViewContext {
    public let basicChartConfigs: BasicChartConfigs
    public let backgroundSkyConfigs: BackgroundSkyConfigs
    public let satelliteMagToRadiusFunction: BackgroundSkyConfigs.StarMagToDisplayRadiusMappingFunction
    public let starManager: AppStarCatalog
    public let julianDateProvider: () -> Double

    public init(
        basicChartConfigs: BasicChartConfigs,
        backgroundSkyConfigs: BackgroundSkyConfigs,
        satelliteMagToRadiusFunction: BackgroundSkyConfigs.StarMagToDisplayRadiusMappingFunction,
        starManager: AppStarCatalog,
        julianDateProvider: @escaping () -> Double
    ) {
        self.basicChartConfigs = basicChartConfigs
        self.backgroundSkyConfigs = backgroundSkyConfigs
        self.satelliteMagToRadiusFunction = satelliteMagToRadiusFunction
        self.starManager = starManager
        self.julianDateProvider = julianDateProvider
    }
}

/// A protocol of real time sky view. Preview code can mock the implementation as a depednency.
public protocol RealtimeSkyView: View {}

/// Always-live planetarium in the second tab. No pass, preview or time-travel controls.
public struct RealtimeSkyViewImpl: RealtimeSkyView {
    @State private var viewModel: RealtimeSkyModel
    let context: RealtimeSkyViewContext
    private let locationSettings: (() -> AnyView)?
    @Environment(\.scenePhase) private var scenePhase
    @State private var visible = false
    @State private var showingLocation = false
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    public init(
        viewModel: RealtimeSkyModel,
        context: RealtimeSkyViewContext,
        backgroundSkyViewFactory: ViewFactory<BackgroundSkyViewContext<EmptyView, EmptyView>, BackgroundSkyView<EmptyView, EmptyView>>,
        locationSettings: (() -> AnyView)? = nil
    ) {
        self.viewModel = viewModel
        self.context = context
        self.locationSettings = locationSettings
    }

    public var body: some View {
        Group {
            if let observer = viewModel.state.observer {
                LiveSkyPlanetarium(viewModel: viewModel, context: context, observer: observer,
                    chooseLocation: locationSettings == nil ? nil : { showingLocation = true })
                    .id(observer)
            } else {
                ContentUnavailableView {
                    Label(Self.Navigation.title, systemImage: "moon.stars")
                } description: {
                    Text("Choose an observer location to see the sky above you.", bundle: .module)
                } actions: {
                    if locationSettings != nil {
                        Button(AppLocalization.text("SettingsOverviewView.observer.header")) { showingLocation = true }
                            .buttonStyle(.borderedProminent)
                    }
                }
                .modifier(AppSurface())
            }
        }
        .analyticsScreen(.skyNow)
        .sheet(isPresented: $showingLocation) {
            NavigationStack {
                locationSettings?()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(AppLocalization.text("Done")) { showingLocation = false }
                        }
                    }
            }
        }
        .onAppear {
            visible = true
            setActive(scenePhase == .active)
        }
        .onDisappear { visible = false; setActive(false) }
        .onChange(of: scenePhase) { _, phase in setActive(visible && phase == .active) }
        .onChange(of: viewModel.state.observer) { _, _ in viewModel.send(.purgeElements) }
        .onReceive(timer) { _ in
            guard visible, scenePhase == .active else { return }
            if !SnapshotEnvironment.isEnabled { viewModel.refreshCatalogIfNeeded() }
            guard let observer = viewModel.state.observer,
                  case .loaded(let satellites) = viewModel.state.satellites else { return }
            viewModel.send(.propagateCurrentEphemerides(satellites, observer: observer,
                julianDate: viewModel.julianDate(at: context.julianDateProvider())))
        }
    }

    private func setActive(_ active: Bool) {
        guard !SnapshotEnvironment.isEnabled else { return }
        viewModel.send(.setRealtimeSkyViewActive(active))
    }
}

private struct LiveSkyPlanetarium: View {
    let viewModel: RealtimeSkyModel
    let context: RealtimeSkyViewContext
    let observer: LatLonAlt
    let chooseLocation: (() -> Void)?
    @StateObject private var controller = PlanetariumController()
    @Environment(\.scenePhase) private var scenePhase
    @State private var visible = false
    @State private var showingSatellites = false
    @AppStorage("planetariumLabels") private var labels = true
    @AppStorage("planetariumLines") private var lines = true
    @AppStorage("planetariumFPS") private var showFPS = false

    private var date: Double { viewModel.julianDate(at: context.julianDateProvider()) }
    private var passing: [RealtimePropagationResult] {
        viewModel.state.resources.displayResults.filter {
            PlanetariumLiveSatellite(result: $0).direction(at: date) != nil
        }.sorted {
            let a = $0.snapshot.visualMagnitude ?? 99, b = $1.snapshot.visualMagnitude ?? 99
            return a == b ? $0.noradIndex < $1.noradIndex : a < b
        }
    }

    var body: some View {
        ZStack {
            PlanetariumSurface(controller: controller).ignoresSafeArea()
            VStack(spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(RealtimeSkyViewImpl.Navigation.title).font(.title2.weight(.semibold))
                        TimelineView(.periodic(from: .now, by: 1)) { _ in
                            Text(Date(julianDate: date), format: .dateTime.hour().minute().second())
                                .font(.caption.monospacedDigit()).foregroundStyle(AppTheme.muted)
                        }
                    }
                    Spacer(minLength: 8)
                    HStack(spacing: 0) {
                        Button {
                            controller.setMotionEnabled(!controller.motionEnabled)
                        } label: {
                            Image(systemName: controller.motionEnabled ? "location.north.line.fill" : "location.north.line")
                                .foregroundStyle(controller.motionEnabled ? AppTheme.accent : AppTheme.text)
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel(AppLocalization.text("Follow Device"))
                        .accessibilityValue(AppLocalization.text(controller.motionEnabled ? "On" : "Off"))
                        .accessibilityIdentifier("planetarium.followDevice")
                        Menu {
                            Toggle(AppLocalization.text("Constellation labels"), systemImage: "textformat", isOn: $labels)
                            Toggle(AppLocalization.text("Constellation lines"), systemImage: "star", isOn: $lines)
                            Toggle(AppLocalization.text("Show FPS"), systemImage: "speedometer", isOn: $showFPS)
                            if let chooseLocation {
                                Button(AppLocalization.text("SettingsOverviewView.observer.header"), systemImage: "mappin.and.ellipse", action: chooseLocation)
                            }
                        } label: {
                            Image(systemName: "ellipsis").frame(width: 44, height: 44)
                        }
                        .accessibilityLabel(AppLocalization.text("Sky options"))
                        .accessibilityIdentifier("planetarium.options")
                    }
                    .buttonStyle(.plain).padding(.horizontal, 4)
                    .glassEffect(.regular, in: Capsule())
                }
                if controller.motionEnabled && !controller.motionAvailable {
                    Text("Motion unavailable · Drag to explore the sky", bundle: .module)
                        .font(.caption).padding(10).background(.ultraThinMaterial, in: Capsule())
                }
                Spacer(minLength: 0)
                PlanetariumSelectionCard(controller: controller, state: controller.selectionState)
                satelliteStatus
                if showFPS, let monitor = controller.renderer?.frameRate {
                    PlanetariumFPSReadout(monitor: monitor)
                }
            }
            .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 12)
            if let error = controller.errorMessage {
                ContentUnavailableView(AppLocalization.text("Planetarium unavailable"), systemImage: "sparkles", description: Text(error))
            }
        }
        .foregroundStyle(AppTheme.text).tint(AppTheme.accent).preferredColorScheme(.dark)
        .sheet(isPresented: $showingSatellites) {
            NavigationStack {
                List(passing, id: \.noradIndex) { result in
                    Button {
                        controller.selectLiveSatellite(result.noradIndex)
                        showingSatellites = false
                    } label: {
                        RealtimeSkySatelliteCell(isFocused: .constant(false), satelliteInfo: result.satelliteInfo, snapshot: result.snapshot)
                    }
                    .buttonStyle(.plain)
                }
                .overlay { if passing.isEmpty { Text("No satellites above the horizon", bundle: .module) } }
                .scrollContentBackground(.hidden).background(AppTheme.background)
                .navigationTitle(AppLocalization.text("Passing now"))
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(AppLocalization.text("Done")) { showingSatellites = false } } }
            }
            .presentationDetents([.medium, .large])
        }
        .onAppear {
            visible = true
            controller.configureSky(observer: observer, starManager: context.starManager, julianDate: date)
            controller.liveDateProvider = { viewModel.julianDate(at: context.julianDateProvider()) }
            controller.updateLiveSatellites(viewModel.state.resources.displayResults)
            controller.setOverlays(labels: labels, lines: lines)
            controller.setActive(scenePhase == .active)
            controller.renderer?.frameRate.setEnabled(showFPS)
        }
        .onDisappear {
            visible = false
            controller.renderer?.frameRate.setEnabled(false)
            controller.stop()
        }
        .onChange(of: scenePhase) { _, phase in
            controller.setActive(visible && phase == .active)
            controller.renderer?.frameRate.setEnabled(showFPS && visible && phase == .active)
        }
        .onChange(of: viewModel.state.resources.displayResults) { _, results in controller.updateLiveSatellites(results) }
        .onChange(of: labels) { _, _ in controller.setOverlays(labels: labels, lines: lines) }
        .onChange(of: lines) { _, _ in controller.setOverlays(labels: labels, lines: lines) }
        .onChange(of: showFPS) { _, value in controller.renderer?.frameRate.setEnabled(value && visible && scenePhase == .active) }
    }

    @ViewBuilder private var satelliteStatus: some View {
        Group {
            switch viewModel.state.satellites {
            case .notLoaded, .loading:
                HStack(spacing: 10) { ProgressView(); Text(RealtimeSkyViewImpl.SatelliteList.loadingText).font(.subheadline) }
            case .failed:
                HStack {
                    Text("Unable to load satellites", bundle: .module).font(.subheadline)
                    Spacer()
                    Button(AppLocalization.text("Retry")) { viewModel.send(.loadElements) }
                }
            case .loaded:
                Button { showingSatellites = true } label: {
                    HStack(spacing: 12) {
                        Image("glyph_satellite").renderingMode(.template).foregroundStyle(AppTheme.accent)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Passing now", bundle: .module).font(.subheadline.weight(.semibold))
                            Text(String.localizedStringWithFormat(AppLocalization.text("%lld above the horizon"), passing.count))
                                .font(.caption).foregroundStyle(AppTheme.muted)
                        }
                        Spacer()
                        Image(systemName: "chevron.up").font(.caption.weight(.semibold))
                    }
                }
                .buttonStyle(.plain).accessibilityIdentifier("skyNow.passingSatellites")
            }
        }
        .frame(maxWidth: .infinity).padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22))
    }
}

extension RealtimeSkyViewImpl {
    enum Navigation {
        static var title: String {
            NSLocalizedString(
                "realtimeSkyView.navigation.title",
                tableName: nil,
                bundle: .module,
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
                bundle: .module,
                value: "Loading satellite catalog...",
                comment: "The loading text for the satellite list"
            )
        }

        static var emptyText: String {
            NSLocalizedString(
                "realtimeSkyView.satelliteList.emptyText",
                tableName: nil,
                bundle: .module,
                value: "No satellite currently visible",
                comment: "The empty text for the satellite list"
            )
        }
    }

    static func satelliteLabelInGraph(_ satelliteInfo: SatelliteInfo) -> String {
        satelliteInfo.ucsSat?.officialName ?? satelliteInfo.satCat?.name ?? satelliteInfo.elements.commonName
    }
}
