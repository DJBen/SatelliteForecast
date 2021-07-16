//
//  SkyChart.swift
//  SatelliteForcast
//
//  Created by Ben Lu on 5/30/21.
//

import CombineRex
import SwiftUI
import SatelliteKit
import SatelliteForcastCore
import StarryNight
import CombineRextensions
import BTree

struct SkyChartSatelliteBackgroundSkyKey: Hashable {
    let observer: LatLonAlt
    let julianDate: Double
}

enum SkyChartUsage: Equatable, Hashable {
    case preview
    case primary
}

enum SkyChartAction {
    case onAppear
    case requestRasterizedBackgroundSky(usage: SkyChartUsage, size: CGSize, key: SkyChartSatelliteBackgroundSkyKey, configs: SkyChartConfigs.BackgroundSky = .preset, traitCollection: UITraitCollection)
    case requestRasterizedSatellitePath(usage: SkyChartUsage, size: CGSize, pass: Pass, traitCollection: UITraitCollection)
    case rasterizedBackgroundSky(UIImage, usage: SkyChartUsage, key: SkyChartSatelliteBackgroundSkyKey)
    /// A satellite path is rasterized, or the rasterized image is read from the cache.
    case rasterizedSatellitePath(UIImage, usage: SkyChartUsage, pass: Pass)
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
        var rise: SnapshotsAroundPass
        var transit: SnapshotsAroundPass
        var set: SnapshotsAroundPass
    }

    enum Mode: Equatable {
        /// Display a placeholder.
        case notReady
        /// Display the sky at julian date. This option will not show any satellite passes.
        case sky(Double, observer: LatLonAlt)
        /// Display a satellite pass. The background sky's date will be the approx time of higest elevation of the pass.
        case pass(Pass, observer: LatLonAlt, snapshots: NotableSnapshots)

        /// The reference julian date for the background sky, if available.
        /// No background sky will be drawn if this returns `nil`.
        var referenceDate: Double? {
            switch self {
            case let .sky(date, _):
                return date
            case let .pass(pass, _, _):
                return pass.rise.julianDate
            case .notReady:
                return nil
            }
        }

        /// The observer corodinate, if available.
        /// Nothing will be drawn if this property is missing.
        var observer: LatLonAlt? {
            switch self {
            case let .pass(_, observer, _), let .sky(_, observer):
                return observer
            case .notReady:
                return nil
            }
        }

        var pass: Pass? {
            switch self {
            case let .pass(pass, observer: _, _):
                return pass
            default:
                return nil
            }
        }
    }

    var mode: Mode = .notReady

    var rasterizedSatellitePaths: [SkyChartUsage: UIImage]?
    var rasterizedBackgroundSky: [SkyChartUsage: UIImage]?

    static func projectPreview(state: AppState, index: Int) -> SkyChartViewState {
        guard let observerCoodinate = state.observerForPasses else {
            return SkyChartViewState(mode: .notReady)
        }

        let displayPass: (Pass, NotableSnapshots)? = {
            switch state.navigationState {
            case let .allPasses(_, noradIndex: noradIndex):
                guard let satelliteState = state.satellites[noradIndex],
                      let passes = satelliteState.passes,
                      index < passes.count else {
                    return nil
                }
                let pass = passes[index]
                let rise = snapshotsAroundPass(satelliteState.snapshots, julianDate: pass.rise.julianDate, selector: .first)!
                let transit = snapshotsAroundPass(satelliteState.snapshots, julianDate: pass.transit.julianDate, selector: .first)!
                let set = snapshotsAroundPass(satelliteState.snapshots, julianDate: pass.set.julianDate, selector: .last)!
                return (pass, NotableSnapshots(rise: rise, transit: transit, set: set))
            default:
                return nil
            }
        }()

        if let displayPass = displayPass {
            return SkyChartViewState(
                mode: Mode.pass(displayPass.0, observer: observerCoodinate, snapshots: displayPass.1),
                rasterizedSatellitePaths: state.skyChartState.rasterizedSatellitePaths[displayPass.0],
                rasterizedBackgroundSky: state.skyChartState.rasterizedBackgroundSky[SkyChartSatelliteBackgroundSkyKey(observer: observerCoodinate, julianDate: displayPass.0.rise.julianDate)]
            )
        } else {
            return .empty
        }
    }

    static func project(state: AppState) -> SkyChartViewState {
        guard let observerCoodinate = state.observerForPasses else {
            return SkyChartViewState(mode: .notReady)
        }
        let selectedPass: (Pass, NotableSnapshots)? = {
            switch state.navigationState {
            case let .pass(_, noradIndex: noradIndex, selectedPassIndex: selectedPassIndex):
                guard let satelliteState = state.satellites[noradIndex],
                      let passes = satelliteState.passes else {
                    return nil
                }
                let pass = passes[selectedPassIndex]
                let rise = snapshotsAroundPass(satelliteState.snapshots, julianDate: pass.rise.julianDate, selector: .first)!
                let transit = snapshotsAroundPass(satelliteState.snapshots, julianDate: pass.transit.julianDate, selector: .first)!
                let set = snapshotsAroundPass(satelliteState.snapshots, julianDate: pass.set.julianDate, selector: .last)!
                return (pass, NotableSnapshots(rise: rise, transit: transit, set: set))
            default:
                return nil
            }
        }()

        if let selectedPass = selectedPass {
            return SkyChartViewState(
                mode: Mode.pass(selectedPass.0, observer: observerCoodinate, snapshots: selectedPass.1),
                rasterizedSatellitePaths: state.skyChartState.rasterizedSatellitePaths[selectedPass.0],
                rasterizedBackgroundSky: state.skyChartState.rasterizedBackgroundSky[SkyChartSatelliteBackgroundSkyKey(observer: observerCoodinate, julianDate: selectedPass.0.rise.julianDate)]
            )
        } else {
            return .empty
        }
    }

    static var empty: SkyChartViewState {
        SkyChartViewState()
    }
}

struct SkyChart: View, Equatable {
    static func == (lhs: SkyChart, rhs: SkyChart) -> Bool {
        lhs.viewModel.state == rhs.viewModel.state
    }

    @ObservedObject private var viewModel: ObservableViewModel<SkyChartAction, SkyChartViewState>
    private let configs: SkyChartConfigs
    private let usage: SkyChartUsage

    @Environment(\.colorScheme) var colorScheme

    init(
        viewModel: ObservableViewModel<SkyChartAction, SkyChartViewState>,
        configs: SkyChartConfigs,
        usage: SkyChartUsage
    ) {
        self.viewModel = viewModel
        self.configs = configs
        self.usage = usage
    }

    private func passInfoLabel(
        observer: LatLonAlt,
        text: String,
        snapshotPair: SkyChartViewState.SnapshotsAroundPass,
        rect: CGRect
    ) -> some View {
        let (rot, offsetFactor) = Self.rotationAndOffsetDirection(snapshotPair: snapshotPair, rect: rect)
        let textPosition = AziEleDst(azim: snapshotPair.first.position.azim, elev: snapshotPair.first.position.elev, dist: 0)
        return HStack(spacing: 2) {
            Path { path in
                path.move(to: CGPoint(x: rect.midX, y: rect.midY))
                path.addLine(to: CGPoint(x: rect.midX + 20, y: rect.midY))
            }
            .stroke(Color.gray)
            .frame(alignment: .leading)

            Text(text)
                .passInfoLabelModifiers()
                .frame(maxWidth: .infinity, alignment: .leading)
                .offset(x: 20 * CGFloat(offsetFactor), y: 0)
        }
        .rotationEffect(.radians(rot))
        .position(Self.point(at: textPosition, rect: rect))
    }

    private var passInfoLabel: some View {
        guard configs.showPassInfoLabels else {
            return AnyView(EmptyView())
        }
        switch viewModel.state.mode {
        case .notReady, .sky(_, observer: _):
            return AnyView(EmptyView())
        case let .pass(pass, observer, snapshots):
            return AnyView(GeometryReader { geometry in
                let rect = geometry.frame(in: .local)

                let dateFormatter: DateFormatter = {
                    let formatter = DateFormatter()
                    formatter.setLocalizedDateFormatFromTemplate("H:mm:ss")
                    return formatter
                }()

                let numberFormatter: NumberFormatter = {
                    let formatter = NumberFormatter()
                    formatter.maximumFractionDigits = 1
                    return formatter
                }()

                ZStack {
                    passInfoLabel(
                        observer: observer,
                        text: "↑\(dateFormatter.string(from: Date(julianDate: pass.rise.julianDate)))",
                        snapshotPair: snapshots.rise,
                        rect: rect
                    )

                    passInfoLabel(
                        observer: observer,
                        text: "↓\(dateFormatter.string(from: Date(julianDate: pass.set.julianDate)))",
                        snapshotPair: snapshots.set,
                        rect: rect
                    )

                    passInfoLabel(
                        observer: observer,
                        text: "\(dateFormatter.string(from: Date(julianDate: pass.transit.julianDate))) \n∠\(numberFormatter.string(from: NSNumber(value: pass.transit.elev))!)°",
                        snapshotPair: snapshots.transit,
                        rect: rect
                    )
                }
            })
        }
    }

    private var satellitePath: some View {
        GeometryReader { geometry in
            let rect = geometry.frame(in: .local)
            let view: AnyView = {
                if rect.size.width == 0 || rect.size.height == 0 {
                    return AnyView(Color.clear)
                } else if let image = viewModel.state.rasterizedSatellitePaths?[usage] {
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
                    if let pass = viewModel.state.mode.pass {
                        viewModel.dispatch(
                            .requestRasterizedSatellitePath(
                                usage: usage,
                                size: contentSize,
                                pass: pass,
                                traitCollection: UITraitCollection(userInterfaceStyle: UIUserInterfaceStyle(colorScheme))
                            )
                        )

                        if let date = viewModel.state.mode.referenceDate, let observer = viewModel.state.mode.observer {
                            viewModel.dispatch(
                                .requestRasterizedBackgroundSky(
                                    usage: usage,
                                    size: contentSize,
                                    key: SkyChartSatelliteBackgroundSkyKey(observer: observer, julianDate: date),
                                    configs: configs.backgroundSky,
                                    traitCollection: UITraitCollection(userInterfaceStyle: UIUserInterfaceStyle(colorScheme))
                                )
                            )
                        }
                }
            }
        }
    }

    var backgroundPath: some View {
        GeometryReader { geometry in
            let rect = geometry.frame(in: .local)
            Path { path in
                path.addArc(
                    center: CGPoint(x: rect.midX, y: rect.midY),
                    radius: Self.radius(fromRect: rect),
                    startAngle: Angle(degrees: 0),
                    endAngle: Angle(degrees: 360),
                    clockwise: false
                )
                path.closeSubpath()
            }
            .stroke(Color("skyChartStroke"), lineWidth: 1)
        }
    }

    var azimuthMarks: some View {
        GeometryReader { geometry in
            let rect = geometry.frame(in: .local)
            Path { path in
                stride(from: 0, to: 360, by: configs.azimuthMarkInterval).forEach { azimuth in
                    let (point1, point2) = Self.azimuthMarkPoints(
                        azimuth: Double(azimuth),
                        length: configs.azimuthMarkLength,
                        rect: rect
                    )
                    path.move(to: point1)
                    path.addLine(to: point2)
                }
            }
            .stroke(Color("skyChartStroke"), lineWidth: 1)
        }
    }

    var azimuthMarkTexts: some View {
        GeometryReader { geometry in
            if let observerCoordinate = viewModel.state.mode.observer {
                let rect = geometry.frame(in: .local)
                let radius = Self.radius(fromRect: rect)
                ZStack {
                    if configs.showAzimuthTexts {
                        ForEach(
                            Array(stride(from: 0, to: 360, by: configs.azimuthMarkInterval)),
                            id: \.self,
                            content: { azimuth in
                                let angle: CGFloat = CGFloat(Double(azimuth + 180) * deg2rad)
                                Text("\(azimuth)°")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                    .position(x: rect.midX, y: rect.midY)
                                    .rotationEffect(
                                        Angle(degrees: -(Double(angle) * rad2deg) + 180)
                                    )
                                    .offset(x: sin(angle) * (radius + 10), y: cos(angle) * (radius + 10))
                            }
                        )
                    }
                    let orientationAnglesNorth: [(String, Double, Double)] = [
                        ("NE", .pi * 0.75, -.pi * 0.5),
                        ("NW", .pi * -0.75, .pi * 0.5),
                        ("SE", .pi * 0.25, -.pi * 0.5),
                        ("SW", .pi * -0.25, .pi * 0.5)
                    ]
                    let orientationAnglesSouth: [(String, Double, Double)] = [
                        ("NE", .pi * -0.75, .pi * 0.5),
                        ("NW", .pi * 0.75, -.pi * 0.5),
                        ("SE", .pi * -0.25, .pi * 0.5),
                        ("SW", .pi * 0.25, -.pi * 0.5)
                    ]
                    let orientationAngles: [(String, Double, Double)] = observerCoordinate.lon > 0 ? orientationAnglesNorth : orientationAnglesSouth
                    if configs.showDirections {
                        ForEach(orientationAngles, id: \.self.0) { (direction, angle, textOrientation) in
                            Text(direction)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .position(x: rect.midX, y: rect.midY)
                                .rotationEffect(
                                    Angle(degrees: (Double(angle + textOrientation) * rad2deg))
                                )
                                .offset(x: sin(CGFloat(angle)) * (radius + configs.directionTextOutset), y: cos(CGFloat(angle)) * (radius + configs.directionTextOutset))
                        }
                    }
                }
            }
        }
    }

    var planetaryBodiesView: some View {
        ZStack {
            if let pass = viewModel.state.mode.pass,
               let observer = viewModel.state.mode.observer {
                ForEach(configs.backgroundSky.visibleBodies, id: \.self) { body in
                    PlanetaryBodyView(
                        planetaryBody: body,
                        label: configs.backgroundSky.bodySymbol,
                        referenceDate: pass.rise.julianDate,
                        observer: observer,
                        sunElevation: pass.sunElevationAtTransit
                    )
                }
            }
        }
    }

    var backgroundSky: some View {
        if let pass = viewModel.state.mode.pass,
           pass.sunElevationAtTransit > -6,
           configs.backgroundSky.hidesStarsDuringDay {
            return AnyView(EmptyView())
        } else {
            return AnyView(GeometryReader { geometry in
                let rect = geometry.frame(in: .local)
                if let image = viewModel.state.rasterizedBackgroundSky?[usage] {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: rect.width, height: rect.height, alignment: .center)
                }
            })
        }
    }

    var loadingIndicator: some View {
        if viewModel.state.rasterizedBackgroundSky == nil || viewModel.state.rasterizedSatellitePaths == nil {
            return AnyView(ProgressView())
        } else {
            return AnyView(EmptyView())
        }
    }

    var body: some View {
        backgroundSky
            .overlay(loadingIndicator)
            .overlay(planetaryBodiesView)
            .overlay(satellitePath)
            .clipShape(Circle())
            .overlay(backgroundPath)
            .overlay(azimuthMarks)
            .overlay(azimuthMarkTexts)
            .overlay(passInfoLabel)
            .onAppear {
                viewModel.dispatch(.onAppear)
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

fileprivate extension View {
    func passInfoLabelModifiers() -> some View {
        return fixedSize()
            .padding(2)
            .background(Color("passInfoLabel_background"))
            .foregroundColor(Color("passInfoLabel_foreground"))
            .font(.caption2)
            .cornerRadius(4)
    }
}

extension ViewProducer where Context == SkyChartContext, ProducedView == SkyChart {
    static func skyChart<S: StoreType>(viewModel: S) -> ViewProducer where S.ActionType == AppAction, S.StateType == AppState {
        ViewProducer<Context, ProducedView> { context in
            SkyChart(
                viewModel: viewModel
                    .projection(
                        action: { AppAction.skyChart($0) },
                        state: { state in
                            switch context.usage {
                            case let .preview(index):
                                return SkyChartViewState.projectPreview(state: state, index: index)
                            case .full:
                                return SkyChartViewState.project(state: state)
                            }
                        }
                    )
                    .asObservableViewModel(
                        initialState: .empty
                    ),
                configs: {
                    switch context.usage {
                    case .preview:
                        return .preview
                    case .full:
                        return .preset
                    }
                }(),
                usage: {
                    switch context.usage {
                    case .preview:
                        return .preview
                    case .full:
                        return .primary
                    }
                }()
            )
        }
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
                        mode: .pass(
                            pass,
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
                                )!
                            )
                        ),
                        rasterizedSatellitePaths: [
                            .primary: SkyChart.rasterizedSatellitePassPath(
                                rect: CGRect(origin: .zero, size: CGSize(width: 388, height: 805)),
                                snapshotsDuringPass: snapshots,
                                illuminatedColor: UIColor(named: "satellitePath_illuminated", in: nil, compatibleWith: traitCollection)!,
                            unlitColor: UIColor(named: "satellitePath_notIlluminated", in: nil, compatibleWith: traitCollection)!
                            )
                        ]
                    )
                ),
                configs: .preset,
                usage: .primary
            )
            .padding(20)
            .preferredColorScheme(colorScheme)
        }

        let (pass2, snapshots2) = tianHePass

        SkyChart(
            viewModel: .mock(
                state: SkyChartViewState(
                    mode: .pass(
                        pass2,
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
                            )!
                        )
                    ),
                    rasterizedSatellitePaths: [
                        .primary: SkyChart.rasterizedSatellitePassPath(
                            rect: CGRect(origin: .zero, size: CGSize(width: 388, height: 805)),
                            snapshotsDuringPass: snapshots2,
                            illuminatedColor: UIColor(Color("satellitePath_illuminated")),
                            unlitColor: UIColor(Color("satellitePath_notIlluminated"))
                        )
                    ]
                )
            ),
            configs: .preset,
            usage: .primary
        )
        .padding(20)

        SkyChart(
            viewModel: .mock(state: .empty),
            configs: .preset,
            usage: .primary
        )
        .padding(20)
        .previewDisplayName("Placeholder")
    }
}
#endif
