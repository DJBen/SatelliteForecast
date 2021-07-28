//
//  SkyChart.swift
//  SatelliteForcast
//
//  Created by Ben Lu on 5/30/21.
//

import CombineRex
import SwiftDate
import SwiftUI
import SwiftUIVisualEffects
import SatelliteKit
import SatelliteForcastCore
import StarryNight
import CombineRextensions
import BTree

/// A key uniquely determining the rendering of a sky chart's background. Same key is guaranteed to render the same background.
struct SkyChartBackgroundSkyKey: Equatable, Hashable {
    let observer: LatLonAlt
    let configs: SkyChartConfigs.BackgroundSky
}

enum SkyChartAction {
    case onAppear

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
    struct SnapshotsAroundPass: Equatable {
        var first: SatelliteSnapshot
        var second: SatelliteSnapshot

        init(_ first: SatelliteSnapshot, _ second: SatelliteSnapshot) {
            self.first = first
            self.second = second
        }
    }

    struct NotableSnapshots: Equatable {
        static func == (lhs: SkyChartViewState.NotableSnapshots, rhs: SkyChartViewState.NotableSnapshots) -> Bool {
            return lhs.rise == rhs.rise && lhs.transit == rhs.transit && lhs.set == rhs.set && lhs.illuminationChanges == rhs.illuminationChanges
        }

        var rise: SnapshotsAroundPass
        var transit: SnapshotsAroundPass
        var set: SnapshotsAroundPass

        struct IlluminationChangeAndSnapshots: Equatable {
            let change: Pass.Illumination.Change
            let snapshots: SnapshotsAroundPass
        }

        var illuminationChanges: BTree<Double, IlluminationChangeAndSnapshots>
    }

    var pass: Pass
    var observer: LatLonAlt
    var snapshots: NotableSnapshots
    var referenceDate: Double
    var snapshotAtReferenceDate: SatelliteSnapshot?
    var quality: SkyChartResources.Quality
    var rasterizedSatellitePaths: UIImage?
    var rasterizedBackgroundSky: UIImage?

    private static func project(
        state: AppState,
        pass: Pass,
        referenceDate: Double,
        quality: SkyChartResources.Quality,
        rasterizedBackgroundSky: UIImage?
    ) -> SkyChartViewState? {
        guard let info = state.satelliteLoaderState[pass.noradIndex],
                let satelliteState = state.satellites[pass.noradIndex],
                let observer = state.observerForPasses else {
            return nil
        }

        let passAndSnapshots: (pass: Pass, snapshots: NotableSnapshots) = {
            let rise = snapshotsAroundPass(satelliteState.snapshots, julianDate: pass.rise.julianDate, selector: .first)!
            let transit = snapshotsAroundPass(satelliteState.snapshots, julianDate: pass.transit.julianDate, selector: .first)!
            let set = snapshotsAroundPass(satelliteState.snapshots, julianDate: pass.set.julianDate, selector: .last)!
            let illuminationChanges = pass.illumination.changes.compactMap { change -> NotableSnapshots.IlluminationChangeAndSnapshots? in
                snapshotsAroundPass(satelliteState.snapshots, julianDate: change.datePosition.julianDate, selector: .first).flatMap { NotableSnapshots.IlluminationChangeAndSnapshots(change: change, snapshots: $0) }
            }
            .reduce(into: BTree<Double, NotableSnapshots.IlluminationChangeAndSnapshots>(), { $0.insert(($1.change.datePosition.julianDate, $1)) })
            let notableSnapshots = NotableSnapshots(rise: rise, transit: transit, set: set, illuminationChanges: illuminationChanges)
            return (pass, notableSnapshots)
        }()

        let snapshotAtReferenceDate: SatelliteSnapshot? = {
            guard (pass.rise.julianDate ..< pass.set.julianDate).contains(referenceDate) else {
                return nil
            }

            return info.satellite.snapshot(
                julianDate: referenceDate,
                observer: observer
            )
        }()

        let rasterizedSatellitePaths: UIImage? = {
            switch quality {
            case .full:
                return state.skyChartState.rasterizedSatellitePaths[passAndSnapshots.pass]
            case .preview:
                return state.skyChartState.previewSatellitePaths[passAndSnapshots.pass]
            }
        }()

        return SkyChartViewState(
            pass: passAndSnapshots.pass,
            observer: observer,
            snapshots: passAndSnapshots.snapshots,
            referenceDate: referenceDate,
            snapshotAtReferenceDate: snapshotAtReferenceDate,
            quality: quality,
            rasterizedSatellitePaths: rasterizedSatellitePaths,
            rasterizedBackgroundSky: rasterizedBackgroundSky
        )
    }

    static func projectPreview(state: AppState, index: Int, backgroundSkyConfigs: SkyChartConfigs.BackgroundSky) -> SkyChartViewState? {
        guard let observer = state.observerForPasses else {
            return nil
        }
        let pass: Pass? = {
            switch state.navigationState {
            case let .allPasses(_, noradIndex: noradIndex):
                guard let satelliteState = state.satellites[noradIndex],
                      let passes = satelliteState.passes,
                      index < passes.count else {
                    return nil
                }
                return passes[index]
            default:
                return nil
            }
        }()

        return pass.flatMap {
            project(
                state: state,
                pass: $0,
                referenceDate: $0.rise.julianDate,
                quality: .preview,
                rasterizedBackgroundSky: state.skyChartState.previewBackgroundSkies[
                    SkyChartBackgroundSkyKey(
                        observer: observer,
                        configs: backgroundSkyConfigs
                    )
                ]?.value(closestTo: $0.rise.julianDate.julianDateRoundedToNearestMinute())
            )
        }
    }

    static func project(state: AppState, backgroundSkyConfigs: SkyChartConfigs.BackgroundSky) -> SkyChartViewState? {
        guard let observer = state.observerForPasses else {
            return nil
        }
        let pass: Pass? = {
            switch state.navigationState {
            case let .pass(_, noradIndex: noradIndex, selectedPassIndex: selectedPassIndex):
                guard let satelliteState = state.satellites[noradIndex],
                      let passes = satelliteState.passes else {
                    return nil
                }
                return passes[selectedPassIndex]
            default:
                return nil
            }
        }()

        return pass.flatMap {
            project(
                state: state,
                pass: $0,
                referenceDate: state.julianDate,
                quality: .full,
                rasterizedBackgroundSky: state.skyChartState.rasterizedBackgroundSky[
                    SkyChartBackgroundSkyKey(
                        observer: observer,
                        configs: backgroundSkyConfigs
                    )
                ]?.value(closestTo: $0.rise.julianDate.julianDateRoundedToNearestMinute())
            )
        }
    }
}

struct SkyChart: View {
    @ObservedObject var viewModel: ObservableViewModel<SkyChartAction, SkyChartViewState?>
    let configs: SkyChartConfigs

    @State private var contentSize: CGSize = .zero

    @Environment(\.colorScheme) var colorScheme

    @ViewBuilder private func unwrapState<Content: View>(@ViewBuilder content: (SkyChartViewState) -> Content) -> some View {
        if let state = viewModel.state {
            content(state)
        }
    }

    @ViewBuilder private var passInfoLabels: some View {
        if configs.showPassInfoLabels {
            unwrapState { state in
                GeometryReader { geometry in
                    let rect = geometry.frame(in: .local)

                    let dateFormatter: DateFormatter = {
                        let formatter = DateFormatter()
                        formatter.setLocalizedDateFormatFromTemplate("H:mm:ss")
                        return formatter
                    }()

                    let numberFormatter: NumberFormatter = {
                        let formatter = NumberFormatter()
                        formatter.maximumFractionDigits = 0
                        return formatter
                    }()

                    ZStack {
                        PassLabel(
                            text: "↑ \(dateFormatter.string(from: Date(julianDate: state.pass.rise.julianDate)))",
                            snapshotPair: state.snapshots.rise,
                            rect: rect
                        )

                        PassLabel(
                            text: "↓ \(dateFormatter.string(from: Date(julianDate: state.pass.set.julianDate)))",
                            snapshotPair: state.snapshots.set,
                            rect: rect
                        )

                        PassLabel(
                            text: "∠\(numberFormatter.string(from: NSNumber(value: state.pass.transit.elev))!)° \(dateFormatter.string(from: Date(julianDate: state.pass.transit.julianDate)))",
                            snapshotPair: state.snapshots.transit,
                            rect: rect
                        )

                        ForEach(state.pass.illumination.changes, id: \.datePosition) { change in
                            if let illuminationChangeAndSnapshots = state.snapshots.illuminationChanges.value(of: change.datePosition.julianDate) {
                                PassLabel(
                                    text: LocalizedStrings.SkyChart.PassLabel.textForIlluminationChange(
                                        change,
                                        dateFormatter: dateFormatter
                                    ),
                                    snapshotPair: illuminationChangeAndSnapshots.snapshots,
                                    rect: rect
                                )
                            }
                        }
                    }
                    .blurEffectStyle(colorScheme == .light ? .systemMaterialDark : .systemMaterialLight)
                    .vibrancyEffectStyle(.fill)
                }
            }
        }
    }

    private var satellitePath: some View {
        unwrapState { state in
            GeometryReader { geometry in
                let rect = geometry.frame(in: .local)
                let view: AnyView = {
                    if rect.size.width == 0 || rect.size.height == 0 {
                        return AnyView(Color.clear)
                    } else if let image = state.rasterizedSatellitePaths {
                        return AnyView(Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: rect.width, height: rect.height, alignment: .center))
                    } else {
                        return AnyView(Color.clear)
                    }
                }()

                view
                    .modifier(SizeModifier())
                    .onPreferenceChange(SizePreferenceKey.self) { contentSize in
                        self.contentSize = contentSize

                        viewModel.dispatch(
                            .requestRasterizedSatellitePath(
                                size: contentSize,
                                quality: state.quality,
                                pass: state.pass,
                                traitCollection: UITraitCollection(userInterfaceStyle: UIUserInterfaceStyle(colorScheme))
                            )
                        )

                        viewModel.dispatch(
                            .requestRasterizedBackgroundSky(
                                size: contentSize,
                                quality: state.quality,
                                // Round date to nearest minute
                                julianDate: state.referenceDate.julianDateRoundedToNearestMinute(),
                                key: SkyChartBackgroundSkyKey(
                                    observer: state.observer,
                                    configs: configs.backgroundSky
                                ),
                                traitCollection: UITraitCollection(userInterfaceStyle: UIUserInterfaceStyle(colorScheme))
                            )
                        )
                    }
                    .onChange(of: state.referenceDate) { newReferenceDate in
                        guard !contentSize.width.isZero && !contentSize.height.isZero else {
                            return
                        }

                        // Show live sky during the pass
                        guard (state.pass.rise.julianDate..<state.pass.set.julianDate).contains(state.referenceDate) else {
                            return
                        }

                        viewModel.dispatch(
                            .requestRasterizedBackgroundSky(
                                size: contentSize,
                                quality: state.quality,
                                // Round date to nearest minute
                                julianDate: newReferenceDate.julianDateRoundedToNearestMinute(),
                                key: SkyChartBackgroundSkyKey(
                                    observer: state.observer,
                                    configs: configs.backgroundSky
                                ),
                                traitCollection: UITraitCollection(userInterfaceStyle: UIUserInterfaceStyle(colorScheme))
                            )
                        )
                    }

            }
        }
    }

    @ViewBuilder var backgroundSky: some View {
         unwrapState { state in
             if !(state.pass.sunElevationAtTransit > -6 &&
                configs.backgroundSky.hidesStarsDuringDay) {
                 GeometryReader { geometry in
                     let rect = geometry.frame(in: .local)
                     if let image = state.rasterizedBackgroundSky {
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
     }

    var planetaryBodiesView: some View {
        unwrapState { state in
            ZStack {
                ForEach(configs.backgroundSky.visibleBodies, id: \.self) { body in
                    PlanetaryBodyView(
                        planetaryBody: body,
                        label: configs.backgroundSky.bodySymbol,
                        referenceDate: state.referenceDate,
                        observer: state.observer,
                        sunElevation: state.pass.sunElevationAtTransit
                    )
                }
            }
        }
    }

    @ViewBuilder var loadingIndicator: some View {
        unwrapState { state in
            if state.rasterizedBackgroundSky == nil || state.rasterizedSatellitePaths == nil {
                ProgressView()
            }
        }
    }

    @ViewBuilder var currentPositionIndicator: some View {
        unwrapState { state in
            if let snapshot = state.snapshotAtReferenceDate {
                SkyChartSatelliteIndicator(
                    state: SkyChartSatelliteIndicatorState(
                        coordinate: snapshot.position
                    )
                )
            }
        }
    }

    var body: some View {
        unwrapState { state in
            SkyChartBackground(
                state: SkyChartBackgroundState(observer: state.observer),
                configs: configs
            )
            .overlay(passInfoLabels)
            .background(
                backgroundSky
                    .overlay(loadingIndicator)
                    .overlay(planetaryBodiesView)
                    .overlay(satellitePath)
                    .clipShape(Circle())
            )
            .onAppear {
                viewModel.dispatch(.onAppear)
            }
        }
    }
}

struct SkyChartContext {
    enum Usage {
        case preview(index: Int)
        case full
    }

    let usage: Usage
}

extension ViewProducer where Context == SkyChartContext, ProducedView == SkyChart {
    static func skyChart<S: StoreType>(viewModel: S) -> ViewProducer where S.ActionType == AppAction, S.StateType == AppState {
        ViewProducer<Context, ProducedView> { context in
            let configs: SkyChartConfigs = {
                switch context.usage {
                case .preview:
                    return .preview
                case .full:
                    return .preset
                }
            }()

            return SkyChart(
                viewModel: viewModel
                    .projection(
                        action: { AppAction.skyChart($0) },
                        state: { state in
                            switch context.usage {
                            case let .preview(index):
                                return SkyChartViewState.projectPreview(
                                    state: state,
                                    index: index,
                                    backgroundSkyConfigs: configs.backgroundSky
                                )
                            case .full:
                                return SkyChartViewState.project(
                                    state: state,
                                    backgroundSkyConfigs: configs.backgroundSky
                                )
                            }
                        }
                    )
                    .asObservableViewModel(
                        initialState: nil
                    ),
                configs: configs
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
    static let issPass: (Pass, BTree<Double, SatelliteSnapshot>) = {
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

        let (passes, fineSnapshots) = sat.findPasses(
            noradIndex: tle.noradIndex,
            observer: LatLonAlt(lat: 32.0669, lon: 118.8251, alt: 0),
            coarseSnapshots: snapshots
        )
        let firstPass = passes.first!
        return (firstPass, fineSnapshots.subtree(from: firstPass.rise.julianDate, through: firstPass.set.julianDate))
    }()

    static let tianHePass: (Pass, BTree<Double, SatelliteSnapshot>) = {
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

        let (passes, fineSnapshots) = sat.findPasses(
            noradIndex: tle.noradIndex,
            observer: LatLonAlt(lat: -27.1570, lon: -109.4274, alt: 0),
            coarseSnapshots: snapshots
        )
        let firstPass = passes.first!
        return (firstPass, fineSnapshots.subtree(from: firstPass.rise.julianDate, through: firstPass.set.julianDate))
    }()

    static var previews: some View {
        let (pass, snapshots) = issPass

        ForEach(ColorScheme.allCases, id: \.self) { colorScheme in
            let traitCollection = UITraitCollection(userInterfaceStyle: UIUserInterfaceStyle(colorScheme))
            SkyChart(
                viewModel: .mock(
                    state: SkyChartViewState(
                        pass: pass,
                        observer: LatLonAlt(lat: 32.0669, lon: 118.8251, alt: 0),
                        snapshots: SkyChartViewState.NotableSnapshots(
                            rise: SkyChartViewState.snapshotsAroundPass(
                                snapshots,
                                julianDate: pass.rise.julianDate,
                                selector: .first
                            )!,
                            transit: SkyChartViewState.snapshotsAroundPass(
                                snapshots,
                                julianDate: pass.transit.julianDate,
                                selector: .first
                            )!,
                            set: SkyChartViewState.snapshotsAroundPass(
                                snapshots,
                                julianDate: pass.set.julianDate,
                                selector: .first
                            )!,
                            illuminationChanges: BTree()
                        ),
                        referenceDate: pass.transit.julianDate.advanced(by: 20 * TimeConstants.sec2day),
                        quality: .full,
                        rasterizedSatellitePaths: SkyChart.rasterizedSatellitePassPath(
                            rect: CGRect(origin: .zero, size: CGSize(width: 388, height: 805)),
                            snapshotsDuringPass: snapshots,
                            illuminatedColor: UIColor(named: "satellitePath_illuminated", in: nil, compatibleWith: traitCollection)!,
                            unlitColor: UIColor(named: "satellitePath_notIlluminated", in: nil, compatibleWith: traitCollection)!
                        )
                    )
                ),
                configs: .preset
            )
            .padding(20)
            .preferredColorScheme(colorScheme)
        }

        let (pass2, snapshots2) = tianHePass

        SkyChart(
            viewModel: .mock(
                state: SkyChartViewState(
                    pass: pass2,
                    observer: LatLonAlt(lat: -27.1570, lon: -109.4274, alt: 0),
                    snapshots: SkyChartViewState.NotableSnapshots(
                        rise: SkyChartViewState.snapshotsAroundPass(
                            snapshots2,
                            julianDate: pass2.rise.julianDate,
                            selector: .first
                        )!,
                        transit: SkyChartViewState.snapshotsAroundPass(
                            snapshots2,
                            julianDate: pass2.transit.julianDate,
                            selector: .first
                        )!,
                        set: SkyChartViewState.snapshotsAroundPass(
                            snapshots2,
                            julianDate: pass2.set.julianDate,
                            selector: .first
                        )!,
                        illuminationChanges: BTree()
                    ),
                    referenceDate: pass2.rise.julianDate,
                    quality: .full,
                    rasterizedSatellitePaths: SkyChart.rasterizedSatellitePassPath(
                        rect: CGRect(origin: .zero, size: CGSize(width: 388, height: 805)),
                        snapshotsDuringPass: snapshots2,
                        illuminatedColor: UIColor(Color("satellitePath_illuminated")),
                        unlitColor: UIColor(Color("satellitePath_notIlluminated"))
                    )
                )
            ),
            configs: .preset
        )
        .padding(20)

        SkyChart(
            viewModel: .mock(state: nil),
            configs: .preset
        )
        .padding(20)
        .previewDisplayName("Placeholder")
    }
}
#endif
