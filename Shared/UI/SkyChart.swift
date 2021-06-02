//
//  SkyChart.swift
//  SatelliteForcast
//
//  Created by Ben Lu on 5/30/21.
//

import SwiftUI
import SatelliteKit

struct SkyChart: View {
    let padding: CGFloat = 0

    var rect: CGRect
    var observerCoordinate: LatLonAlt
    var skyReferenceDate: Date
    var sortedDateHorizontalCoordinates: [DateHorizontalCoordinate]

    var radius: CGFloat {
        return min(rect.width - padding * 2, rect.height - padding * 2) / 2
    }

    private func pointAtHorizontalCoordinate(_ coordinate: AziEleDst) -> CGPoint {
        let dist = (90 - coordinate.elev) / 90.0 * Double(radius)
        let xOffset = sin(coordinate.azim * deg2rad) * dist
        let yOffset = cos(coordinate.azim * deg2rad) * dist
        return CGPoint(x: rect.midX - CGFloat(xOffset), y: rect.midY - CGFloat(yOffset))
    }

    private func azimuthMarkPoints(azimuth: Double, length: CGFloat) -> (CGPoint, CGPoint) {
        func pointWithAzimuth(_ azim: Double, dist: Double) -> CGPoint {
            let xOffset = sin(azim * deg2rad) * dist
            let yOffset = cos(azim * deg2rad) * dist
            return CGPoint(x: rect.midX - CGFloat(xOffset), y: rect.midY - CGFloat(yOffset))
        }
        return (pointWithAzimuth(azimuth, dist: Double(radius)), pointWithAzimuth(azimuth, dist: Double(radius + length)))
    }

    private func pathFromSortedDateHorizontalCoordinates(_ sortedDateHorizontalCoordinates: [DateHorizontalCoordinate]) -> Path {
        Path { path in
            for (i, dateHorizonalCoordinate) in sortedDateHorizontalCoordinates.enumerated() {
                let coordinate = dateHorizonalCoordinate.horizontalCoordinate
                let point = pointAtHorizontalCoordinate(coordinate)
                if i == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
        }
    }

    var backgroundPath: Path {
        Path { path in
            path.addArc(
                center: CGPoint(x: rect.midX, y: rect.midY),
                radius: radius,
                startAngle: Angle(degrees: 0),
                endAngle: Angle(degrees: 360),
                clockwise: false
            )
            path.closeSubpath()
        }
    }

    var starPath: Path {
        Path { path in
            let stars = Star.magitudeLessThan(4.5)
            for star in stars {
                let (alt, azi) = azel(time: skyReferenceDate, site: (observerCoordinate.lat, observerCoordinate.lon), cele: cartesianToRaDec(star.physicalInfo.coordinate))
                if alt < 0 {
                    continue
                }
                let point = pointAtHorizontalCoordinate(AziEleDst(azim: azi, elev: alt, dist: 0))
                path.move(to: point)
                let radius = CGFloat(3.5 * exp(0.375 * -star.physicalInfo.apparentMagnitude))
                path.addEllipse(in: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
            }
        }
    }

    var constellationLinesPath: Path {
        Path { path in
            for constellation in Constellation.all {
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
                    if alt1 < 0 || alt2 < 0 {
                        continue
                    }
                    let point1 = pointAtHorizontalCoordinate(AziEleDst(azim: azi1, elev: alt1, dist: 0))
                    let point2 = pointAtHorizontalCoordinate(AziEleDst(azim: azi2, elev: alt2, dist: 0))
                    path.move(to: point1)
                    path.addLine(to: point2)
                }
            }
        }
    }

    var azimuthMarks: Path {
        Path { path in
            stride(from: 0, to: 360, by: 10).forEach { azimuth in
                let (point1, point2) = azimuthMarkPoints(azimuth: Double(azimuth), length: 3)
                path.move(to: point1)
                path.addLine(to: point2)
            }
        }
    }

    var azimuthMarkTexts: some View {
        ZStack {
            ForEach(
                Array(stride(from: 0, to: 360, by: 10)),
                id: \.self,
                content: { azimuth in
                    let angle: CGFloat = CGFloat(Double(azimuth + 180) * deg2rad)
                    Text("\(azimuth)º")
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .rotationEffect(
                            Angle(degrees: -(Double(angle) * rad2deg) + 180)
                        )
                        .offset(x: sin(angle) * (radius + 10), y: cos(angle) * (radius + 10))
                }
            )
            Text("NE")
                .font(.subheadline)
                .foregroundColor(.gray)
                .rotationEffect(
                    Angle(degrees: -(Double(.pi * 0.75) * rad2deg) + 180)
                )
                .offset(x: sin(.pi * 0.75) * (radius + 40), y: cos(.pi * 0.75) * (radius + 40))
            Text("NW")
                .font(.subheadline)
                .foregroundColor(.gray)
                .rotationEffect(
                    Angle(degrees: -(Double(.pi * 1.25) * rad2deg) + 180)
                )
                .offset(x: sin(.pi * 1.25) * (radius + 40), y: cos(.pi * 1.25) * (radius + 40))
            Text("SE")
                .font(.subheadline)
                .foregroundColor(.gray)
                .rotationEffect(
                    Angle(degrees: -(Double(.pi * 0.25) * rad2deg) + 180)
                )
                .offset(x: sin(.pi * 0.25) * (radius + 40), y: cos(.pi * 0.25) * (radius + 40))
            Text("SW")
                .font(.subheadline)
                .foregroundColor(.gray)
                .rotationEffect(
                    Angle(degrees: -(Double(.pi * 1.75) * rad2deg) + 180)
                )
                .offset(x: sin(.pi * 1.75) * (radius + 40), y: cos(.pi * 1.75) * (radius + 40))
        }
    }

    var body: some View {
            pathFromSortedDateHorizontalCoordinates(sortedDateHorizontalCoordinates)
                    .stroke(Color.black, lineWidth: 1)
            .overlay(
                starPath
                    .fill()
                    .foregroundColor(.black)
            )
            .overlay(
                constellationLinesPath
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            .clipShape(
                Circle()
            )
            .overlay(
                backgroundPath
                    .stroke(Color.black, lineWidth: 1)
            )
            .overlay(
                azimuthMarks
                    .stroke(Color.black, lineWidth: 1)
            )
            .overlay(
                azimuthMarkTexts
            )
    }
}

struct SkyChart_Previews: PreviewProvider {
    static let viewModel: SatelliteWidgetViewModel = {
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

        return SatelliteWidgetViewModel(
            satelliteName: tle.commonName,
            sortedDateHorizontalCoordinates: (0..<40)
                .map { date.addingTimeInterval(Double($0 * 10)) }
                .map { (currentDate) -> DateHorizontalCoordinate in
                    let aziEleDst = sat.topPosition(
                        julianDays: currentDate.julianDate,
                        observer: LatLonAlt(lat: 32.0669, lon: 118.8251, alt: 0)
                    )
                    return DateHorizontalCoordinate(date: currentDate, horizontalCoordinate: aziEleDst)
                }
        )
    }()

    static var previews: some View {
        GeometryReader { geometry in
            SkyChart(
                rect: geometry.frame(in: .local),
                observerCoordinate: LatLonAlt(lat: 32.0669, lon: 118.8251, alt: 0),
                skyReferenceDate: {
                    let formatter = ISO8601DateFormatter()
                    return formatter.date(from: "2021-06-02T20:40:00+0800")!
                }(),
                sortedDateHorizontalCoordinates: viewModel.sortedDateHorizontalCoordinates
            )
        }
    }
}
