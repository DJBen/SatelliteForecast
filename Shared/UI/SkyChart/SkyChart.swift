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

struct SkyChartConfigs: Equatable {
    /// The degree interval between each pair of azimuth marks
    var azimuthMarkInterval: Int = 15

    /// The length of azimuth marks
    var azimuthMarkLength: CGFloat = 3

    static var preset: SkyChartConfigs {
        return SkyChartConfigs()
    }
}

enum SkyChartAction {
    case onAppear
    case loadedBackgroundSky(stars: [Star], constellations: Set<Constellation>)
}

/// The root state of sky charts.
struct SkyChartRootState: Equatable {
    var skyReferenceDate: Date
    var passInformation: [PassInformation] = []
    var configs: SkyChartConfigs = .preset

    // Background sky that is async loaded
    var stars: [Star] = []
    var constellations: Set<Constellation> = []
}

/// A state used in a single sky chart view
enum SkyChartState: Equatable {
    case locationNotDetermined(
        configs: SkyChartConfigs = .preset
    )
    case observer(
        LatLonAlt,
        skyReferenceDate: Date,
        passInformation: PassInformation?,
        configs: SkyChartConfigs = .preset,
        stars: [Star] = [],
        constellations: Set<Constellation> = []
    )

    var configs: SkyChartConfigs {
        switch self {
        case let .locationNotDetermined(configs),
             let .observer(_, skyReferenceDate: _, passInformation: _, configs: configs, stars: _, constellations: _):
            return configs
        }
    }

    static func project(state: AppState) -> SkyChartState {
        if let observerCoodinate = state.coreLocationState.location.map(LatLonAlt.init) {
            return .observer(
                observerCoodinate,
                skyReferenceDate: state.skyChartState.skyReferenceDate,
                // TODO #3: Support multiple pass charts
                passInformation: state.skyChartState.passInformation.first,
                configs: state.skyChartConfigs,
                stars: state.skyChartState.stars,
                constellations: state.skyChartState.constellations
            )
        } else {
            return .locationNotDetermined(configs: state.skyChartConfigs)
        }
    }
}

struct SkyChart: View {
    private let viewModel: ObservableViewModel<SkyChartAction, SkyChartState>

    init(viewModel: ObservableViewModel<SkyChartAction, SkyChartState>) {
        self.viewModel = viewModel
    }

    private func radius(fromRect rect: CGRect) -> CGFloat {
        return min(rect.width, rect.height) / 2
    }

    private func pointAtHorizontalCoordinate(_ coordinate: AziEleDst, rect: CGRect) -> CGPoint {
        let dist = (90 - coordinate.elev) / 90.0 * Double(radius(fromRect: rect))
        let xOffset = sin(coordinate.azim * deg2rad) * dist
        let yOffset = cos(coordinate.azim * deg2rad) * dist
        return CGPoint(x: rect.midX - CGFloat(xOffset), y: rect.midY - CGFloat(yOffset))
    }

    private func azimuthMarkPoints(azimuth: Double, length: CGFloat, rect: CGRect) -> (CGPoint, CGPoint) {
        func pointWithAzimuth(_ azim: Double, dist: Double) -> CGPoint {
            let xOffset = sin(azim * deg2rad) * dist
            let yOffset = cos(azim * deg2rad) * dist
            return CGPoint(x: rect.midX - CGFloat(xOffset), y: rect.midY - CGFloat(yOffset))
        }
        return (
            pointWithAzimuth(azimuth, dist: Double(radius(fromRect: rect))),
            pointWithAzimuth(azimuth, dist: Double(radius(fromRect: rect) + length))
        )
    }

    private var pathFromSortedSatelliteSnapshots: some View {
        switch viewModel.state {
        case let .observer(observerCoordinate, skyReferenceDate, passInformation, _, _, _):
            return AnyView(GeometryReader { geometry in
                let rect = geometry.frame(in: .local)

                if let passInformation = passInformation {
                    if passInformation.snapshots.isEmpty {
                        EmptyView()
                    } else {
                        let indexIDs = (0..<passInformation.snapshots.count - 1).map {
                            ($0, "\(String(describing: passInformation.risesAt))_ref-\(String(describing: skyReferenceDate))_\(observerCoordinate)_\($0)")
                        }
                        ZStack {
                            ForEach(indexIDs, id: \.1) { (i, _) in
                                Path { path in
                                    let point = pointAtHorizontalCoordinate(passInformation.snapshots[i].position, rect: rect)
                                    let nextPoint = pointAtHorizontalCoordinate(passInformation.snapshots[i + 1].position, rect: rect)
                                    path.move(to: point)
                                    path.addLine(to: nextPoint)
                                }
                                .stroke(
                                    passInformation.snapshots[i].isIlluminated ? Color("satellitePath_illuminated") : Color("satellitePath_notIlluminated"),
                                    lineWidth: 1
                                )
                            }
                        }
                    }
                }
            })
        case .locationNotDetermined(_):
            return AnyView(EmptyView())
        }
    }

    var backgroundPath: some View {
        GeometryReader { geometry in
            let rect = geometry.frame(in: .local)
            Path { path in
                path.addArc(
                    center: CGPoint(x: rect.midX, y: rect.midY),
                    radius: radius(fromRect: rect),
                    startAngle: Angle(degrees: 0),
                    endAngle: Angle(degrees: 360),
                    clockwise: false
                )
                path.closeSubpath()
            }
            .stroke(Color.black, lineWidth: 1)
        }
    }

    var starPath: some View {
        switch viewModel.state {
        case let .observer(observerCoordinate, skyReferenceDate, _, _, stars, _):
            return AnyView(GeometryReader { geometry in
                let rect = geometry.frame(in: .local)
                Path { path in
                    for star in stars {
                        let (alt, azi) = azel(
                            time: skyReferenceDate,
                            site: (observerCoordinate.lat, observerCoordinate.lon),
                            cele: cartesianToRaDec(star.physicalInfo.coordinate))
                        if alt < 0 {
                            continue
                        }
                        let point = pointAtHorizontalCoordinate(AziEleDst(azim: azi, elev: alt, dist: 0), rect: rect)
                        path.move(to: point)
                        let radius = CGFloat(3 * exp(0.425 * -star.physicalInfo.apparentMagnitude))
                        path.addEllipse(in: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
                    }
                }
                .fill()
                .foregroundColor(.black)
            })
        case .locationNotDetermined(_):
            return AnyView(EmptyView())
        }
    }

    var constellationLinesPath: some View {
        switch viewModel.state {
        case let .observer(observerCoordinate, skyReferenceDate, _, _, _, constellations):
            return AnyView(GeometryReader { geometry in
                let rect = geometry.frame(in: .local)
                Path { path in
                    for constellation in constellations {
                        guard let center = constellation.displayCenter else {
                            continue
                        }
                        let (alt, _) = azel(time: skyReferenceDate, site: (observerCoordinate.lat, observerCoordinate.lon), cele: cartesianToRaDec(center))
                        if alt < 0 {
                            continue
                        }
                        for line in constellation.connectionLines {
                            let (alt1, azi1) = azel(time: skyReferenceDate, site: (observerCoordinate.lat, observerCoordinate.lon), cele: cartesianToRaDec(line.star1.physicalInfo.coordinate))
                            let (alt2, azi2) = azel(time: skyReferenceDate, site: (observerCoordinate.lat, observerCoordinate.lon), cele: cartesianToRaDec(line.star2.physicalInfo.coordinate))
                            let point1 = pointAtHorizontalCoordinate(AziEleDst(azim: azi1, elev: alt1, dist: 0), rect: rect)
                            let point2 = pointAtHorizontalCoordinate(AziEleDst(azim: azi2, elev: alt2, dist: 0), rect: rect)
                            path.move(to: point1)
                            path.addLine(to: point2)
                        }
                    }
                }
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            })
        case .locationNotDetermined(_):
            return AnyView(EmptyView())
        }
    }

    var azimuthMarks: some View {
        GeometryReader { geometry in
            let rect = geometry.frame(in: .local)
            Path { path in
                stride(from: 0, to: 360, by: viewModel.state.configs.azimuthMarkInterval).forEach { azimuth in
                    let (point1, point2) = azimuthMarkPoints(azimuth: Double(azimuth), length: viewModel.state.configs.azimuthMarkLength, rect: rect)
                    path.move(to: point1)
                    path.addLine(to: point2)
                }
            }
            .stroke(Color.black, lineWidth: 1)
        }
    }

    var azimuthMarkTexts: some View {
        switch viewModel.state {
        case let .observer(observerCoordinate, _, _, _, _, _):
            return AnyView(GeometryReader { geometry in
                let rect = geometry.frame(in: .local)
                let radius = radius(fromRect: rect)
                ZStack {
                    ForEach(
                        Array(stride(from: 0, to: 360, by: viewModel.state.configs.azimuthMarkInterval)),
                        id: \.self,
                        content: { azimuth in
                            let angle: CGFloat = CGFloat(Double(azimuth + 180) * deg2rad)
                            Text("\(azimuth)º")
                                .font(.caption2)
                                .foregroundColor(.gray)
                                .position(x: rect.midX, y: rect.midY)
                                .rotationEffect(
                                    Angle(degrees: -(Double(angle) * rad2deg) + 180)
                                )
                                .offset(x: sin(angle) * (radius + 10), y: cos(angle) * (radius + 10))
                        }
                    )
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
                    ForEach(orientationAngles, id: \.self.0) { (direction, angle, textOrientation) in
                        Text(direction)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .position(x: rect.midX, y: rect.midY)
                            .rotationEffect(
                                Angle(degrees: (Double(angle + textOrientation) * rad2deg))
                            )
                            .offset(x: sin(CGFloat(angle)) * (radius + 30), y: cos(CGFloat(angle)) * (radius + 30))
                    }
                }
            })
        case .locationNotDetermined(_):
            return AnyView(EmptyView())
        }
    }

    func planetView<Content: View, Label: View>(
        getRaDec: (Double) -> (ra: Double, dec: Double),
        planetViewGenerator: @escaping () -> Content,
        @ViewBuilder labelBuilder: @escaping () -> Label
    ) -> some View {
        switch viewModel.state {
        case let .observer(observerCoordinate, skyReferenceDate, _, _, _, _):
            let (alt, azi) = azel(
                time: skyReferenceDate,
                site: (observerCoordinate.lat, observerCoordinate.lon),
                cele: getRaDec(skyReferenceDate.julianDate)
            )
            let planetCoordinate = AziEleDst(azim: azi, elev: alt, dist: 0)

            if planetCoordinate.elev < 0 {
                return AnyView(EmptyView())
            }

            return AnyView(GeometryReader { geometry in
                let rect = geometry.frame(in: .local)
                ZStack {
                    HStack(spacing: 0) {
                        planetViewGenerator()

                        labelBuilder()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .position(
                        pointAtHorizontalCoordinate(
                            planetCoordinate,
                            rect: rect
                        )
                    )
                }
            })
        case .locationNotDetermined(_):
            return AnyView(EmptyView())
        }
    }

    var sunView: some View {
        GeometryReader { geometry in
            let rect = geometry.frame(in: .local)
            planetView(
                getRaDec: solarGeo,
                planetViewGenerator: {
                    Path { path in
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
                },
                labelBuilder: {
                    Text("Sun")
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .offset(x: 10)
                }
            )
        }
    }

    var moonView: some View {
        GeometryReader { geometry in
            let rect = geometry.frame(in: .local)
            planetView(
                getRaDec: lunarGeo,
                planetViewGenerator: {
                    Path { path in
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
                },
                labelBuilder: {
                    Text("Moon")
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .offset(x: 8)
                }
            )
        }
    }

    var body: some View {
        pathFromSortedSatelliteSnapshots
            .overlay(starPath)
            .overlay(constellationLinesPath)
            .clipShape(Circle())
            .overlay(backgroundPath)
            .overlay(azimuthMarks)
            .overlay(azimuthMarkTexts)
            .overlay(moonView)
            .overlay(sunView)
            .id(UUID())
            .onAppear {
                viewModel.dispatch(.onAppear)
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
                        state: SkyChartState.project(state:)
                    )
                    .asObservableViewModel(
                        initialState: .locationNotDetermined()
                    )
            )
        }
    }
}

struct SkyChart_Previews: PreviewProvider {
    static let issPass: PassInformation = {
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

        return sat.findPasses(
            observer: LatLonAlt(lat: 32.0669, lon: 118.8251, alt: 0),
            param: .dateRange(date..<date.addingTimeInterval(800))
        )
        .first!
    }()

    static let tianHePass: PassInformation = {
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

        return sat.findPasses(
            observer: LatLonAlt(lat: -27.1570, lon: -109.4274, alt: 0),
            param: .dateRange(date..<date.addingTimeInterval(800))
        )
        .first!
    }()

    static var previews: some View {
        let stars = Star.magitudeLessThan(4.5)
        let constellations = Constellation.all

        SkyChart(
            viewModel: .mock(
                state: .observer(
                    LatLonAlt(lat: 32.0669, lon: 118.8251, alt: 0),
                    skyReferenceDate: {
                        let formatter = ISO8601DateFormatter()
                        return formatter.date(from: "2021-06-02T20:40:00+0800")!
                    }(),
                    passInformation: issPass,
                    configs: .preset,
                    stars: stars,
                    constellations: constellations
                )
            )
        )
        .padding(20)

        SkyChart(
            viewModel: .mock(
                state: .observer(
                    LatLonAlt(lat: -27.1570, lon: -109.4274, alt: 0),
                    skyReferenceDate: {
                        let formatter = ISO8601DateFormatter()
                        return formatter.date(from: "2021-06-02T06:34:46-0600")!
                    }(),
                    passInformation: tianHePass,
                    configs: .preset,
                    stars: stars,
                    constellations: constellations
                )
            )
        )
        .padding(20)
    }
}
