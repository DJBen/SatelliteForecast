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

/// The root state of sky charts.
struct SkyChartRootState: Equatable {
    var configs: SkyChartConfigs = .preset

    // Background sky that is async loaded
    var stars: [Star] = []
    var constellations: Set<Constellation> = []

    /// A cache of the satellite paths that are ready for display.
    /// Instead of redrawing the pass consisting of thousands of points at each display,
    /// the cached version is just a cheap `UIImage`.
    var rasterizedSatellitePaths: [PassInformation: UIImage] = [:]

    static var empty: SkyChartRootState {
        return SkyChartRootState()
    }
}

enum SkyChartAction {
    case onAppear
    case loadedBackgroundSky(
        stars: [Star],
        constellations: Set<Constellation>
    )
    /// A satellite path is rasterized, or the rasterized image is read from the cache.
    case rasterizedSatellitePath(UIImage, pass: PassInformation)
}

/// A state used in a single sky chart view
struct SkyChartViewState: Equatable {
    enum Mode: Equatable {
        static func == (lhs: SkyChartViewState.Mode, rhs: SkyChartViewState.Mode) -> Bool {
            switch (lhs, rhs) {
            case (.notReady, .notReady):
                return true
            case let (.sky(d1, obs1), .sky(d2, obs2)):
                return d1 == d2 && obs1 == obs2
            case let (.pass(p1, s1, obs1), .pass(p2, s2, obs2)):
                return p1 == p2 && s1 == s2 && obs1 == obs2
            default:
                return false
            }
        }

        /// Display a placeholder.
        case notReady
        /// Display the sky at julian date. This option will not show any satellite passes.
        case sky(Double, observer: LatLonAlt)
        /// Display a satellite pass. The background sky's date will be the approx time of higest elevation of the pass.
        case pass(PassInformation, snapshotsDuringPass: Map<Double, SatelliteSnapshot>, observer: LatLonAlt)

        /// The reference julian date for the background sky, if available.
        /// No background sky will be drawn if this returns `nil`.
        var referenceDate: Double? {
            switch self {
            case let .sky(date, _):
                return date
            case let .pass(passInformation, _, _):
                return passInformation.rise.julianDate
            case .notReady:
                return nil
            }
        }

        /// The observer corodinate, if available.
        /// Nothing will be drawn if this property is missing.
        var observer: LatLonAlt? {
            switch self {
            case let .pass(_, _, observer), let .sky(_, observer):
                return observer
            case .notReady:
                return nil
            }
        }

        var passInformation: PassInformation? {
            switch self {
            case let .pass(passInformation, _, observer: _):
                return passInformation
            default:
                return nil
            }
        }
    }

    var mode: Mode = .notReady
    var stars: [Star] = []
    var constellations: Set<Constellation> = []

    /// The satellite path will use this image if provided.
    var rasterizedSatellitePath: UIImage?

    struct DirectionArrow: Equatable {
        let azimuth: Double
        // 0 to 1
        let dist: Double
        let orientation: Double
    }
    // Derived information
    var directionArrow: DirectionArrow?

    static func projectPreview(state: AppState, index: Int) -> SkyChartViewState {
        guard let observerCoodinate = state.coreLocationState.location.map(LatLonAlt.init) else {
            return SkyChartViewState(mode: .notReady)
        }
        let displayPass: (PassInformation, Map<Double, SatelliteSnapshot>)? = {
            switch state.navigationState {
            case let .allPasses(noradIndex: noradIndex):
                guard let satelliteState = state.satellites[noradIndex], index < satelliteState.passes.count else {
                    return nil
                }
                let pass = satelliteState.passes[index]
                // TODO: conditionally generate submap, or rasterized path
                let subMap = satelliteState.snapshots.submap(from: pass.rise.julianDate, through: pass.set.julianDate)
                return (pass, subMap)
            default:
                return nil
            }
        }()
        return SkyChartViewState(
            mode: displayPass.map { Mode.pass($0.0, snapshotsDuringPass: $0.1, observer: observerCoodinate) } ?? .notReady,
            stars: state.skyChartState.stars,
            constellations: state.skyChartState.constellations,
            rasterizedSatellitePath: displayPass.flatMap { state.skyChartState.rasterizedSatellitePaths[$0.0] }
        )
    }

    static func projectPassingMode(state: AppState) -> SkyChartViewState {
        guard let observerCoodinate = state.coreLocationState.location.map(LatLonAlt.init) else {
            return SkyChartViewState(mode: .notReady)
        }
        let selectedPass: (PassInformation, Map<Double, SatelliteSnapshot>)? = {
            switch state.navigationState {
            case let .pass(noradIndex: noradIndex, selectedPassIndex: selectedPassIndex):
                guard let satelliteState = state.satellites[noradIndex] else {
                    return nil
                }
                let pass = satelliteState.passes[selectedPassIndex]
                let subMap = satelliteState.snapshots.submap(from: pass.rise.julianDate, through: pass.set.julianDate)
                return (pass, subMap)
            default:
                return nil
            }
        }()
        return SkyChartViewState(
            mode: selectedPass.map { Mode.pass($0.0, snapshotsDuringPass: $0.1, observer: observerCoodinate) } ?? .notReady,
            stars: state.skyChartState.stars,
            constellations: state.skyChartState.constellations,
            rasterizedSatellitePath: selectedPass.flatMap { state.skyChartState.rasterizedSatellitePaths[$0.0] }
        )
    }

    static var empty: SkyChartViewState {
        SkyChartViewState()
    }
}

struct SkyChart: View {
    private let viewModel: ObservableViewModel<SkyChartAction, SkyChartViewState>
    private let configs: SkyChartConfigs

    init(
        viewModel: ObservableViewModel<SkyChartAction, SkyChartViewState>,
        configs: SkyChartConfigs
    ) {
        self.viewModel = viewModel
        self.configs = configs
    }

    struct PassInfoModifier: ViewModifier {
        func body(content: Content) -> some View {
            return content.fixedSize()
                .padding(2)
                .background(Color("passInfoLabel_background"))
                .foregroundColor(Color("passInfoLabel_foreground"))
                .font(.caption2)
                .cornerRadius(4)
        }
    }

    private var passInfoLabel: some View {
        guard configs.showPassInfoLabels else {
            return AnyView(EmptyView())
        }
        switch viewModel.state.mode {
        case .notReady, .sky(_, observer: _):
            return AnyView(EmptyView())
        case let .pass(pass, snapshotsDuringPass, _):
            return AnyView(GeometryReader { geometry in
                let rect = geometry.frame(in: .local)
                let formatter: DateFormatter = {
                    let formatter = DateFormatter()
                    formatter.setLocalizedDateFormatFromTemplate("H:mm:ss")
                    return formatter
                }()
                let numberFormatter: NumberFormatter = {
                    let formatter = NumberFormatter()
                    formatter.usesSignificantDigits = true
                    formatter.maximumSignificantDigits = 3
                    return formatter
                }()
                ZStack {
                    if let snapshot = snapshotsDuringPass.submap(from: pass.rise.julianDate, to: pass.rise.julianDate + TimeConstants.sec2day * 10).first {
                        let textPosition = AziEleDst(azim: snapshot.1.position.azim, elev: snapshot.1.position.elev + 15, dist: 0)
                        Text("↑\(formatter.string(from: Date(julianDate: pass.rise.julianDate)))")
                            .modifier(PassInfoModifier())
                            .position(Self.point(at: textPosition, rect: rect))
                    }
                    if let snapshot = snapshotsDuringPass.submap(from: pass.set.julianDate - TimeConstants.sec2day * 10, to: pass.set.julianDate).last {
                        let textPosition = AziEleDst(azim: snapshot.1.position.azim, elev: snapshot.1.position.elev + 15, dist: 0)
                        Text("↓\(formatter.string(from: Date(julianDate: pass.set.julianDate)))")
                            .modifier(PassInfoModifier())
                            .position(Self.point(at: textPosition, rect: rect))
                    }
                    if let higestElevSnapshot = snapshotsDuringPass.submap(from: pass.transit.julianDate - TimeConstants.sec2day * 2, to: pass.transit.julianDate + TimeConstants.sec2day * 10).first {
                        let textPosition = AziEleDst(azim: higestElevSnapshot.1.position.azim, elev: higestElevSnapshot.1.position.elev + 15, dist: 0)
                        Text("\(formatter.string(from: Date(julianDate: pass.transit.julianDate))) \n∠\(numberFormatter.string(from: NSNumber(value: pass.transit.elev))!)°")
                            .modifier(PassInfoModifier())
                            .position(Self.point(at: textPosition, rect: rect))
                    }
                }
            })
        }
    }

    private var satellitePath: some View {
        GeometryReader { geometry in
            let rect = geometry.frame(in: .local)

            if rect.size.width == 0 || rect.size.height == 0 {
                AnyView(EmptyView())
            } else if let image = viewModel.state.rasterizedSatellitePath {
                AnyView(Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: rect.width, height: rect.height, alignment: .center))
            } else {
                AnyView(EmptyView())
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

    var starPath: some View {
        GeometryReader { geometry in
            if configs.backgroundSky.showStars,
               let referenceDate = viewModel.state.mode.referenceDate,
               let observerCoordinate = viewModel.state.mode.observer {
                let rect = geometry.frame(in: .local)
                Path { path in
                    for star in viewModel.state.stars {
                        let (alt, azi) = azel(
                            julianDate: referenceDate,
                            site: (observerCoordinate.lat, observerCoordinate.lon),
                            cele: cartesianToRaDec(star.physicalInfo.coordinate))
                        if alt < 0 {
                            continue
                        }
                        let point = Self.point(at: AziEleDst(azim: azi, elev: alt, dist: 0), rect: rect)
                        path.move(to: point)
                        let radius = CGFloat(3 * exp(0.425 * -star.physicalInfo.apparentMagnitude))
                        path.addEllipse(in: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
                    }
                }
                .fill()
                .foregroundColor(Color("star"))
            }
        }

    }

    var constellationLinesPath: some View {
        GeometryReader { geometry in
            if configs.backgroundSky.showConstellationLines,
               let referenceDate = viewModel.state.mode.referenceDate,
               let observerCoordinate = viewModel.state.mode.observer {
                let rect = geometry.frame(in: .local)
                Path { path in
                    for constellation in viewModel.state.constellations {
                        guard let center = constellation.displayCenter else {
                            continue
                        }
                        let (alt, _) = azel(julianDate: referenceDate, site: (observerCoordinate.lat, observerCoordinate.lon), cele: cartesianToRaDec(center))
                        if alt < 0 {
                            continue
                        }
                        for line in constellation.connectionLines {
                            let (alt1, azi1) = azel(julianDate: referenceDate, site: (observerCoordinate.lat, observerCoordinate.lon), cele: cartesianToRaDec(line.star1.physicalInfo.coordinate))
                            let (alt2, azi2) = azel(julianDate: referenceDate, site: (observerCoordinate.lat, observerCoordinate.lon), cele: cartesianToRaDec(line.star2.physicalInfo.coordinate))
                            let point1 = Self.point(at: AziEleDst(azim: azi1, elev: alt1, dist: 0), rect: rect)
                            let point2 = Self.point(at: AziEleDst(azim: azi2, elev: alt2, dist: 0), rect: rect)
                            path.move(to: point1)
                            path.addLine(to: point2)
                        }
                    }
                }
                .stroke(Color("constellationLine"), lineWidth: 1)
            }
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

    func planetView<Content: View>(
        getRaDec: (Double) -> (ra: Double, dec: Double),
        @ViewBuilder planetViewGenerator: @escaping (AziEleDst) -> Content
    ) -> some View {
        if let referenceDate = viewModel.state.mode.referenceDate,
           let observerCoordinate = viewModel.state.mode.observer {
            let (alt, azi) = azel(
                julianDate: referenceDate,
                site: (observerCoordinate.lat, observerCoordinate.lon),
                cele: getRaDec(referenceDate)
            )
            let planetCoordinate = AziEleDst(azim: azi, elev: alt, dist: 0)

            if planetCoordinate.elev < 0 {
                return AnyView(EmptyView())
            }

            return AnyView(GeometryReader { geometry in
                ZStack {
                    planetViewGenerator(planetCoordinate)
                }
            })
        } else {
            return AnyView(EmptyView())
        }
    }

    var sunView: some View {
        if configs.backgroundSky.visibileBodies.contains(.sun) {
            return AnyView(GeometryReader { geometry in
                let rect = geometry.frame(in: .local)
                planetView(getRaDec: solarGeo) { planetCoordinate in
                    let path = Path { path in
                        path.addArc(
                            center: CGPoint(x: rect.midX, y: rect.midY),
                            radius: 8,
                            startAngle: Angle(degrees: 0),
                            endAngle: Angle(degrees: 360),
                            clockwise: false
                        )
                    }
                    .fill()
                    .foregroundColor(.yellow)
                    .shadow(color: .yellow, radius: 12, x: 0.0, y: 0.0)

                    switch configs.backgroundSky.bodySymbol {
                    case .text:
                        HStack(spacing: 0) {
                            path

                            Text("Sun")
                                .font(.caption2)
                                .foregroundColor(.orange)
                                .offset(x: 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .position(Self.point(at: planetCoordinate, rect: rect))

                    case .symbol:
                        ZStack {
                            path
                            Text("☉")
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                                .frame(alignment: .center)
                        }
                        .position(Self.point(at: planetCoordinate, rect: rect))
                    }
                }
            })
        } else {
            return AnyView(EmptyView())
        }
    }

    var moonView: some View {
        if configs.backgroundSky.visibileBodies.contains(.moon) {
            return AnyView(GeometryReader { geometry in
                let rect = geometry.frame(in: .local)
                planetView(getRaDec: lunarGeo) { planetCoordinate in
                    let path = Path { path in
                        path.addArc(
                            center: CGPoint(x: rect.midX, y: rect.midY),
                            radius: 5,
                            startAngle: Angle(degrees: 0),
                            endAngle: Angle(degrees: 360),
                            clockwise: false
                        )
                    }
                    .fill()
                    .foregroundColor(.gray)
                    .shadow(color: .yellow.opacity(0.7), radius: 8, x: 0.0, y: 0.0)

                    switch configs.backgroundSky.bodySymbol {
                    case .text:
                        HStack(spacing: 0) {
                            path
                            Text("Moon")
                                .font(.caption2)
                                .foregroundColor(.blue)
                                .offset(x: 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .position(Self.point(at: planetCoordinate, rect: rect))

                    case .symbol:
                        ZStack {
                            path
                            Text("☾")
                                .font(.system(size: 8))
                                .foregroundColor(.white)
                                .frame(alignment: .center)
                        }
                        .position(Self.point(at: planetCoordinate, rect: rect))
                    }
                }
            })
        } else {
            return AnyView(EmptyView())
        }
    }

    var body: some View {
        starPath
            .overlay(constellationLinesPath)
            .overlay(moonView)
            .overlay(sunView)
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

extension ViewProducer where Context == Int, ProducedView == SkyChart {
    static func skyChartAsPreview<S: StoreType>(viewModel: S) -> ViewProducer where S.ActionType == AppAction, S.StateType == AppState {
        ViewProducer<Context, ProducedView> { index in
            SkyChart(
                viewModel: viewModel
                    .projection(
                        action: { AppAction.skyChart($0) },
                        state: { SkyChartViewState.projectPreview(state: $0, index: index) }
                    )
                    .asObservableViewModel(
                        initialState: .empty
                    ),
                configs: SkyChartConfigs(
                    backgroundSky: SkyChartConfigs.BackgroundSky(
                        showStars: false,
                        showConstellationLines: false,
                        visibileBodies: [.sun, .moon],
                        bodySymbol: .symbol
                    ),
                    showAzimuthTexts: false,
                    azimuthMarkInterval: 90,
                    azimuthMarkLength: 2,
                    showDirections: false,
                    showPassInfoLabels: false
                )
            )
        }
    }
}

extension ViewProducer where Context == Void, ProducedView == SkyChart {
    static func skyChart<S: StoreType>(viewModel: S) -> ViewProducer where S.ActionType == AppAction, S.StateType == AppState {
        ViewProducer<Context, ProducedView> {
            SkyChart(
                viewModel: viewModel
                    .projection(
                        action: { AppAction.skyChart($0) },
                        state: SkyChartViewState.projectPassingMode(state:)
                    )
                    .asObservableViewModel(
                        initialState: .empty
                    ),
                configs: .preset
            )
        }
    }
}

struct SkyChart_Previews: PreviewProvider {
    static let issPass: (PassInformation, Map<Double, SatelliteSnapshot>) = {
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
            observer: LatLonAlt(lat: 32.0669, lon: 118.8251, alt: 0),
            coarseSnapshots: snapshots
        )
        let firstPass = passes.first!
        return (firstPass, fineSnapshots.submap(from: firstPass.rise.julianDate, through: firstPass.set.julianDate))
    }()

    static let tianHePass: (PassInformation, Map<Double, SatelliteSnapshot>) = {
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
            observer: LatLonAlt(lat: -27.1570, lon: -109.4274, alt: 0),
            coarseSnapshots: snapshots
        )
        let firstPass = passes.first!
        return (firstPass, fineSnapshots.submap(from: firstPass.rise.julianDate, through: firstPass.set.julianDate))
    }()

    static var previews: some View {
        let stars = Star.magitudeLessThan(4.5)
        let constellations = Constellation.all
        let (pass, snapshots) = issPass

        ForEach(ColorScheme.allCases, id: \.self) {
            SkyChart(
                viewModel: .mock(
                    state: SkyChartViewState(
                        mode: .pass(
                            pass,
                            snapshotsDuringPass: snapshots,
                            observer: LatLonAlt(lat: 32.0669, lon: 118.8251, alt: 0)
                        ),
                        stars: stars,
                        constellations: constellations,
                        rasterizedSatellitePath: SkyChart.rasterizedPath(
                            rect: CGRect(origin: .zero, size: CGSize(width: 375, height: 375)),
                            snapshotsDuringPass: snapshots,
                            illuminatedColor: UIColor(Color("satellitePath_illuminated")),
                            unlitColor: UIColor(Color("satellitePath_notIlluminated"))
                        )
                    )
                ),
                configs: .preset
            )
            .padding(20)
            .preferredColorScheme($0)
        }

        let (pass2, snapshots2) = tianHePass

        SkyChart(
            viewModel: .mock(
                state: SkyChartViewState(
                    mode: .pass(
                        pass2,
                        snapshotsDuringPass: snapshots2,
                        observer: LatLonAlt(lat: -27.1570, lon: -109.4274, alt: 0)
                    ),
                    stars: stars,
                    constellations: constellations,
                    rasterizedSatellitePath: SkyChart.rasterizedPath(
                        rect: CGRect(origin: .zero, size: CGSize(width: 375, height: 375)),
                        snapshotsDuringPass: snapshots,
                        illuminatedColor: UIColor(Color("satellitePath_illuminated")),
                        unlitColor: UIColor(Color("satellitePath_notIlluminated"))
                    )
                )
            ),
            configs: .preset
        )
        .padding(20)

        SkyChart(
            viewModel: .mock(state: .empty),
            configs: .preset
        )
        .padding(20)
        .previewDisplayName("Placeholder")
    }
}
