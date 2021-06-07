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

public enum SkyChartAction {

}

public struct SkyChartState: Equatable {
    /// The observer coordinate in latitude (in degrees), longitude (in degrees) and altitude (in meters)
    public let observerCoordinate: LatLonAlt

    /// The reference date for the background sky.
    public let skyReferenceDate: Date

    /// A satellite trail consisting of pairs of dates and horizontal coordinates.
    /// Satellite trail will be plotted as a curve.
    public let satelliteTrail: [SatelliteSnapshot]

    /// The degree interval between each pair of azimuth marks
    public let azimuthMarkInterval: Int = 15

    /// The length of azimuth marks
    public let azimuthMarkLength: CGFloat = 3
}

public struct SkyChart: View {
    private let viewModel: ObservableViewModel<SkyChartAction, SkyChartState>

    public init(viewModel: ObservableViewModel<SkyChartAction, SkyChartState>) {
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

    private func pathFromSortedSatelliteSnapshots(_ satelliteSnapshots: [SatelliteSnapshot], rect: CGRect) -> some View {
        ZStack {
            ForEach(0..<satelliteSnapshots.count - 1) { i in
                Path { path in
                    let point = pointAtHorizontalCoordinate(satelliteSnapshots[i].position, rect: rect)
                    let nextPoint = pointAtHorizontalCoordinate(satelliteSnapshots[i + 1].position, rect: rect)
                    path.move(to: point)
                    path.addLine(to: nextPoint)
                }
                .stroke(
                    satelliteSnapshots[i].isIlluminated ? Color("satellitePath_illuminated") : Color("satellitePath_notIlluminated"),
                    lineWidth: 1
                )
            }
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
        GeometryReader { geometry in
            let rect = geometry.frame(in: .local)
            Path { path in
                let stars = Star.magitudeLessThan(4.5)
                for star in stars {
                    let (alt, azi) = azel(
                        time: viewModel.state.skyReferenceDate,
                        site: (viewModel.state.observerCoordinate.lat, viewModel.state.observerCoordinate.lon),
                        cele: cartesianToRaDec(star.physicalInfo.coordinate))
                    if alt < 0 {
                        continue
                    }
                    let point = pointAtHorizontalCoordinate(AziEleDst(azim: azi, elev: alt, dist: 0), rect: rect)
                    path.move(to: point)
                    let radius = CGFloat(3.5 * exp(0.375 * -star.physicalInfo.apparentMagnitude))
                    path.addEllipse(in: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
                }
            }
            .fill()
            .foregroundColor(.black)
        }
    }

    var constellationLinesPath: some View {
        GeometryReader { geometry in
            let rect = geometry.frame(in: .local)
            Path { path in
                for constellation in Constellation.all {
                    guard let center = constellation.displayCenter else {
                        continue
                    }
                    let (alt, _) = azel(time: viewModel.state.skyReferenceDate, site: (viewModel.state.observerCoordinate.lat, viewModel.state.observerCoordinate.lon), cele: cartesianToRaDec(center))
                    if alt < 0 {
                        continue
                    }
                    for line in constellation.connectionLines {
                        let (alt1, azi1) = azel(time: viewModel.state.skyReferenceDate, site: (viewModel.state.observerCoordinate.lat, viewModel.state.observerCoordinate.lon), cele: cartesianToRaDec(line.star1.physicalInfo.coordinate))
                        let (alt2, azi2) = azel(time: viewModel.state.skyReferenceDate, site: (viewModel.state.observerCoordinate.lat, viewModel.state.observerCoordinate.lon), cele: cartesianToRaDec(line.star2.physicalInfo.coordinate))
                        let point1 = pointAtHorizontalCoordinate(AziEleDst(azim: azi1, elev: alt1, dist: 0), rect: rect)
                        let point2 = pointAtHorizontalCoordinate(AziEleDst(azim: azi2, elev: alt2, dist: 0), rect: rect)
                        path.move(to: point1)
                        path.addLine(to: point2)
                    }
                }
            }
            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        }
    }

    var azimuthMarks: some View {
        GeometryReader { geometry in
            let rect = geometry.frame(in: .local)
            Path { path in
                stride(from: 0, to: 360, by: viewModel.state.azimuthMarkInterval).forEach { azimuth in
                    let (point1, point2) = azimuthMarkPoints(azimuth: Double(azimuth), length: viewModel.state.azimuthMarkLength, rect: rect)
                    path.move(to: point1)
                    path.addLine(to: point2)
                }
            }
            .stroke(Color.black, lineWidth: 1)
        }
    }

    var azimuthMarkTexts: some View {
        GeometryReader { geometry in
            let rect = geometry.frame(in: .local)
            let radius = radius(fromRect: rect)
            ZStack {
                ForEach(
                    Array(stride(from: 0, to: 360, by: viewModel.state.azimuthMarkInterval)),
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
                let orientationAngles: [(String, Double, Double)] = viewModel.state.observerCoordinate.lon > 0 ? orientationAnglesNorth : orientationAnglesSouth
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
        }
    }

    var moonCoordinate: AziEleDst {
        let (alt, azi) = azel(
            time: viewModel.state.skyReferenceDate,
            site: (viewModel.state.observerCoordinate.lat, viewModel.state.observerCoordinate.lon),
            cele: lunarGeo(julianDays: viewModel.state.skyReferenceDate.julianDate)
        )
        return AziEleDst(azim: azi, elev: alt, dist: 0)
    }

    public var body: some View {
        GeometryReader { geometry in
            let rect = geometry.frame(in: .local)
            pathFromSortedSatelliteSnapshots(
                viewModel.state.satelliteTrail,
                rect: rect
            )
            .overlay(starPath)
            .overlay(constellationLinesPath)
            .clipShape(Circle())
            .overlay(backgroundPath)
            .overlay(azimuthMarks)
            .overlay(azimuthMarkTexts)
            .overlay(
                HStack(spacing: 10) {
                    Path { path in
                        if moonCoordinate.elev < 0 {
                            return
                        }
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

                    Text("Moon")
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .position(
                    pointAtHorizontalCoordinate(
                        moonCoordinate,
                        rect: rect
                    )
                )
            )
        }
    }
}

struct SkyChart_Previews: PreviewProvider {
    static let issTrail: [SatelliteSnapshot] = {
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
        .snapshots
    }()

    static let tianHeTrail: [SatelliteSnapshot] = {
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
        .snapshots
    }()

    static var previews: some View {
        SkyChart(
            viewModel: .mock(
                state: SkyChartState(
                    observerCoordinate: LatLonAlt(lat: 32.0669, lon: 118.8251, alt: 0),
                    skyReferenceDate: {
                        let formatter = ISO8601DateFormatter()
                        return formatter.date(from: "2021-06-02T20:40:00+0800")!
                    }(),
                    satelliteTrail: issTrail
                )
            )
        )
        .padding(20)

        SkyChart(
            viewModel: .mock(
                state: SkyChartState(
                    observerCoordinate: LatLonAlt(lat: -27.1570, lon: -109.4274, alt: 0),
                    skyReferenceDate: {
                        let formatter = ISO8601DateFormatter()
                        return formatter.date(from: "2021-06-02T06:34:46-0600")!
                    }(),
                    satelliteTrail: tianHeTrail
                )
            )
        )
        .padding(20)
    }
}
