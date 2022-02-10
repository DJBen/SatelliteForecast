//
//  SkyChart.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 5/30/21.
//

import CombineRex
import SwiftDate
import SwiftUI
import SwiftUIVisualEffects
import SatelliteKit
import SatelliteForecastCore
import StarryNight
import CombineRextensions
import BTree

/// A key uniquely determining the rendering of a sky chart's background. Same key is guaranteed to render the same background.
struct SkyChartBackgroundSkyKey: Equatable, Hashable {
    let observer: LatLonAlt
    let configs: SkyChartConfigs.BackgroundSky
}

enum SkyChartAction {
    /// Request a rasterized version of the background sky.
    /// The caller should group the call and reduce frequency by rounding the date to a nearest minute, for example.
    case requestRasterizedBackgroundSky(size: CGSize, quality: SkyChartResources.Quality, julianDate: Double, key: SkyChartBackgroundSkyKey, traitCollection: UITraitCollection)
    case requestRasterizedSatellitePath(size: CGSize, quality: SkyChartResources.Quality, pass: Pass, traitCollection: UITraitCollection)
    case rasterizedBackgroundSky(UIImage, quality: SkyChartResources.Quality, julianDate: Double, key: SkyChartBackgroundSkyKey)
    /// A satellite path is rasterized, or the rasterized image is read from the cache.
    case rasterizedSatellitePath(UIImage, quality: SkyChartResources.Quality, pass: Pass)
}

/// A state used in a single sky chart view
struct SkyChartViewState: Equatable {
    var referenceDate: Double = 0
    /// The julian date offset between the julian date in display and the actual julian date.
    /// This property is being used by the dynamic label
    var julianDateOffset: Double = 0
    var resources: SkyChartResources = .init()
    
    static func project(
        appState: AppState
    ) -> SkyChartViewState {
        return SkyChartViewState(
            referenceDate: appState.currentDate,
            julianDateOffset: appState.debugMenu.effectiveOffset,
            resources: appState.skyChartState
        )
    }
}

struct SkyChart: View {
    @ObservedObject var viewModel: ObservableViewModel<SkyChartAction, SkyChartViewState>
    let context: SkyChartContext

    @State private var contentSize: CGSize = .zero

    @Environment(\.colorScheme) var colorScheme

    @ViewBuilder private var passInfoLabels: some View {
        if context.configs.showPassInfoLabels {
            GeometryReader { geometry in
                let rect = geometry.frame(in: .local)

                ZStack {
                    PassLabel(
                        text: "↑ \(Self.labelDateFormatter.string(from: Date(julianDate: context.pass.rise.julianDate)))",
                        snapshotPair: context.notableSnapshots.rise,
                        rect: rect,
                        modifierFactory: PassLabelModifier.init(rotationAngle:)
                    )

                    PassLabel(
                        text: "↓ \(Self.labelDateFormatter.string(from: Date(julianDate: context.pass.set.julianDate)))",
                        snapshotPair: context.notableSnapshots.set,
                        rect: rect,
                        modifierFactory: PassLabelModifier.init(rotationAngle:)
                    )

                    PassLabel(
                        text: "∠\(Self.labelAngleFormatter.string(from: NSNumber(value: context.pass.transit.elev))!)° \(Self.labelDateFormatter.string(from: Date(julianDate: context.pass.transit.julianDate)))",
                        snapshotPair: context.notableSnapshots.transit,
                        rect: rect,
                        modifierFactory: PassLabelModifier.init(rotationAngle:)
                    )

                    ForEach(context.pass.illumination.changes, id: \.datePosition) { change in
                        if let illuminationChangeAndSnapshots = context.notableSnapshots.illuminationChanges.value(of: change.datePosition.julianDate) {
                            PassLabel(
                                text: LocalizedStrings.SkyChart.PassLabel.textForIlluminationChange(
                                    change,
                                    dateFormatter: Self.labelDateFormatter
                                ),
                                snapshotPair: illuminationChangeAndSnapshots.snapshots,
                                rect: rect,
                                modifierFactory: PassLabelModifier.init(rotationAngle:)
                            )
                        }
                    }
                }
                .blurEffectStyle(colorScheme == .light ? .systemMaterialDark : .systemMaterialLight)
                .vibrancyEffectStyle(.fill)
            }
        }
    }

    private var rasterizedSatellitePath: UIImage? {
        switch context.quality {
        case .full:
            return viewModel.state.resources.rasterizedSatellitePaths[context.pass]
        case .preview:
            return viewModel.state.resources.previewSatellitePaths[context.pass]
        }
    }

    private var rasterizedBackgroundSky: UIImage? {
        let imageCache: [SkyChartBackgroundSkyKey: BTree<Double, UIImage>] = (
            context.quality == .full ?
            viewModel.state.resources.rasterizedBackgroundSky
            : viewModel.state.resources.previewBackgroundSkies
        )

        return imageCache[
            SkyChartBackgroundSkyKey(
                observer: context.observer,
                configs: context.configs.backgroundSky
            )
        ]?.value(
            closestTo: backgroundSkyJulianDateKey
        )
    }

    private var backgroundSkyJulianDateKey: Double {
        if (context.pass.rise.julianDate..<context.pass.set.julianDate).contains(viewModel.state.referenceDate) {
            return viewModel.state.referenceDate.julianDateRoundedToNearestMinute()
        }
        return context.pass.rise.julianDate.julianDateRoundedToNearestMinute()
    }

    private var satellitePath: some View {
        GeometryReader { geometry in
            let rect = geometry.frame(in: .local)
            let view: AnyView = {
                if rect.size.width == 0 || rect.size.height == 0 {
                    return AnyView(Color.clear)
                } else if let image = rasterizedSatellitePath {
                    return AnyView(Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: rect.width, height: rect.height, alignment: .center))
                } else {
                    return AnyView(Color.clear)
                }
            }()

            view.modifier(SizeModifier())
            .onPreferenceChange(SizePreferenceKey.self) { contentSize in
                self.contentSize = contentSize

                viewModel.dispatch(
                    .requestRasterizedSatellitePath(
                        size: contentSize,
                        quality: context.quality,
                        pass: context.pass,
                        traitCollection: UITraitCollection(userInterfaceStyle: UIUserInterfaceStyle(colorScheme))
                    )
                )

                viewModel.dispatch(
                    .requestRasterizedBackgroundSky(
                        size: contentSize,
                        quality: context.quality,
                        julianDate: backgroundSkyJulianDateKey,
                        key: SkyChartBackgroundSkyKey(
                            observer: context.observer,
                            configs: context.configs.backgroundSky
                        ),
                        traitCollection: UITraitCollection(userInterfaceStyle: UIUserInterfaceStyle(colorScheme))
                    )
                )
            }
            .onChange(of: viewModel.state.referenceDate) { newReferenceDate in
                guard !contentSize.width.isZero && !contentSize.height.isZero else {
                    return
                }

                // Show live sky during the pass
                guard (context.pass.rise.julianDate..<context.pass.set.julianDate).contains(viewModel.state.referenceDate) else {
                    return
                }

                viewModel.dispatch(
                    .requestRasterizedBackgroundSky(
                        size: contentSize,
                        quality: context.quality,
                        // Round date to nearest minute
                        julianDate: newReferenceDate.julianDateRoundedToNearestMinute(),
                        key: SkyChartBackgroundSkyKey(
                            observer: context.observer,
                            configs: context.configs.backgroundSky
                        ),
                        traitCollection: UITraitCollection(userInterfaceStyle: UIUserInterfaceStyle(colorScheme))
                    )
                )
            }
        }
    }

    @ViewBuilder var backgroundSky: some View {
         if !(context.pass.sunElevationAtTransit > -6 &&
              context.configs.backgroundSky.hidesStarsDuringDay) {
             GeometryReader { geometry in
                 let rect = geometry.frame(in: .local)
                 if let image = rasterizedBackgroundSky {
                     Image(uiImage: image)
                         .resizable()
                         .aspectRatio(contentMode: .fit)
                         .frame(width: rect.width, height: rect.height, alignment: .center)
                 }
             }
         } else {
             // Needs to have a non-empty view so that views on top of it will have a non-zero size
             Color.clear
         }
     }

    var planetaryBodiesView: some View {
        ZStack {
            ForEach(context.configs.backgroundSky.visibleBodies, id: \.self) { body in
                PlanetaryBodyView(
                    planetaryBody: body,
                    label: context.configs.backgroundSky.bodySymbol,
                    referenceDate: viewModel.state.referenceDate,
                    observer: context.observer,
                    sunElevation: context.pass.sunElevationAtTransit
                )
            }
        }
    }

    @ViewBuilder var loadingIndicator: some View {
        if rasterizedBackgroundSky == nil || rasterizedSatellitePath == nil {
            ProgressView()
        }
    }

    var body: some View {
        SkyChartBackground(
            state: SkyChartBackgroundState(observer: context.observer),
            configs: context.configs
        )
        .equatable()
        .overlay(passInfoLabels)
        .overlay(
            SkyChartDynamicIndicator(
                state: SkyChartDynamicIndicatorState(
                    satellite: context.satelliteInfo.satellite,
                    pass: context.pass,
                    observer: context.observer,
                    julianDateOffset: viewModel.state.julianDateOffset
                )
            ).clipShape(Circle())
        )
        .background(
            backgroundSky.overlay(loadingIndicator)
            .overlay(planetaryBodiesView)
            .overlay(satellitePath)
            .clipShape(Circle())
        )
    }
}

struct SkyChartContext {
    let satelliteInfo: SatelliteInfo
    let snapshots: BTree<Double, SatelliteSnapshot>
    let observer: LatLonAlt
    let pass: Pass
    let notableSnapshots: NotableSnapshots
    let configs: SkyChartConfigs
    let quality: SkyChartResources.Quality
}

extension ViewProducer where Context == SkyChartContext, ProducedView == SkyChart {
    static func skyChart<S: StoreType>(viewModel: S) -> ViewProducer where S.ActionType == AppAction, S.StateType == AppState {
        ViewProducer<Context, ProducedView> { context in
            return SkyChart(
                viewModel: viewModel
                    .projection(
                        action: { AppAction.skyChart($0) },
                        state: SkyChartViewState.project(appState:)
                    )
                    .asObservableViewModel(
                        initialState: SkyChartViewState()
                    ),
                context: context
            )
        }
    }
}

fileprivate extension Double {
    func julianDateRoundedToNearestMinute() -> Double {
        Date(julianDate: self).dateRoundedAt(at: .toMins(1)).julianDate
    }
}

#if DEBUG
struct SkyChart_Previews: PreviewProvider {
    static let issPass: (Satellite, PassSnapshots) = {
        let tle = try! TLE(
            raw: """
            ISS (ZARYA)
            1 25544U 98067A   21152.11066515  .00000451  00000-0  16375-4 0  9992
            2 25544  51.6453  62.2423 0003364  52.3737  88.5313 15.48937685286109
            """
        )
        let sat = Satellite(withTLE: tle)

        let formatter = ISO8601DateFormatter()
        let date = formatter.date(from: "2021-06-02T20:35:30+0800")!

        let observer = LatLonAlt(lat: 32.0669, lon: 118.8251, alt: 0)
        let snapshots = sat.snapshots(
            observer: observer,
            julianDateRange: date.julianDate..<date.addingTimeInterval(800).julianDate
        )

        let passSnapshots = sat.findPasses(
            noradIndex: tle.noradIndex,
            observer: LatLonAlt(lat: 32.0669, lon: 118.8251, alt: 0),
            coarseSnapshots: snapshots
        )
        let firstPassSnapshots = passSnapshots.first!
        return (sat, firstPassSnapshots)
    }()

    static let tianHePass: (Satellite, PassSnapshots) = {
        let tle = try! TLE(
            raw: """
            TIANHE
            1 48274U 21035A   21152.91865056  .00003057  00000-0  33542-4 0  9993
            2 48274  41.4713  16.3199 0005053  25.9394 109.3813 15.65195495  5304
            """
        )
        let sat = Satellite(withTLE: tle)

        let formatter = ISO8601DateFormatter()
        let date = formatter.date(from: "2021-06-02T06:29:00-0600")!

        let observer = LatLonAlt(lat: -27.1570, lon: -109.4274, alt: 0)
        let snapshots = sat.snapshots(
            observer: observer,
            julianDateRange: date.julianDate..<date.addingTimeInterval(800).julianDate
        )

        let passSnapshots = sat.findPasses(
            noradIndex: tle.noradIndex,
            observer: LatLonAlt(lat: -27.1570, lon: -109.4274, alt: 0),
            coarseSnapshots: snapshots
        )
        let firstPassSnapshots = passSnapshots.first!
        return (sat, firstPassSnapshots)
    }()

    static var previews: some View {
        let (satellite, passSnapshots) = issPass

        ForEach(ColorScheme.allCases, id: \.self) { colorScheme in
            let traitCollection = UITraitCollection(userInterfaceStyle: UIUserInterfaceStyle(colorScheme))
            SkyChart(
                viewModel: .mock(
                    state: SkyChartViewState(
                        referenceDate: passSnapshots.pass.transit.julianDate.advanced(by: 20 * TimeConstants.sec2day),
                        resources: SkyChartResources(
                            rasterizedSatellitePaths: [
                                passSnapshots.pass: SkyChart.rasterizedSatellitePassPath(
                                    params: SatellitePassPathRenderParams(
                                        rect: CGRect(origin: .zero, size: CGSize(width: 388, height: 805)),
                                        snapshotsDuringPass: passSnapshots.snapshots,
                                        illuminatedColor: UIColor(named: "satellitePath_illuminated", in: nil, compatibleWith: traitCollection)!,
                                        unlitColor: UIColor(named: "satellitePath_notIlluminated", in: nil, compatibleWith: traitCollection)!
                                    )
                                )
                            ],
                            previewSatellitePaths: [:],
                            rasterizedBackgroundSky: [:],
                            previewBackgroundSkies: [:]
                        )
                    )
                ),
                context: SkyChartContext(
                    satelliteInfo: SatelliteInfo(noradIndex: 48274, satellite: satellite),
                    snapshots: passSnapshots.snapshots,
                    observer: LatLonAlt(lat: 32.0669, lon: 118.8251, alt: 0),
                    pass: passSnapshots.pass,
                    notableSnapshots: passSnapshots.notableSnapshots,
                    configs: .preset,
                    quality: .full
                )
            )
            .padding(20)
            .preferredColorScheme(colorScheme)
        }

        let (satellite2, passSnapshots2) = tianHePass

        SkyChart(
            viewModel: .mock(
                state: SkyChartViewState(
                    referenceDate: passSnapshots2.pass.rise.julianDate,
                    resources: SkyChartResources(
                        rasterizedSatellitePaths: [
                            passSnapshots2.pass: SkyChart.rasterizedSatellitePassPath(
                                params: SatellitePassPathRenderParams(
                                    rect: CGRect(origin: .zero, size: CGSize(width: 388, height: 805)),
                                    snapshotsDuringPass: passSnapshots2.snapshots,
                                    illuminatedColor: UIColor(Color("satellitePath_illuminated")),
                                    unlitColor: UIColor(Color("satellitePath_notIlluminated"))
                                )
                            )
                        ],
                        previewSatellitePaths: [:],
                        rasterizedBackgroundSky: [:],
                        previewBackgroundSkies: [:]
                    )
                )
            ),
            context: SkyChartContext(
                satelliteInfo: SatelliteInfo(noradIndex: 48274, satellite: satellite2),
                snapshots: passSnapshots2.snapshots,
                observer: LatLonAlt(lat: -27.1570, lon: -109.4274, alt: 0),
                pass: passSnapshots2.pass,
                notableSnapshots: passSnapshots2.notableSnapshots,
                configs: .preset,
                quality: .full
            )
        )
        .padding(20)

        SkyChart(
            viewModel: .mock(state: .init()),
            context: SkyChartContext(
                satelliteInfo: SatelliteInfo(noradIndex: 48274, satellite: satellite2),
                snapshots: passSnapshots2.snapshots,
                observer: LatLonAlt(lat: -27.1570, lon: -109.4274, alt: 0),
                pass: passSnapshots2.pass,
                notableSnapshots: passSnapshots2.notableSnapshots,
                configs: .preset,
                quality: .full
            )
        )
        .padding(20)
        .previewDisplayName("Placeholder")
    }
}
#endif
