//
//  SkyChart.swift
//  SatelliteForcast
//
//  Created by Ben Lu on 5/30/21.
//

import SwiftUI
import SatelliteKit

struct SkyChart: View {
    let padding: CGFloat = 10

    var rect: CGRect
    var observerCoordinate: LatLonAlt
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

    private func pathFromSortedDateHorizontalCoordinates(_ sortedDateHorizontalCoordinates: [DateHorizontalCoordinate]) -> Path {
        var path = Path()
        for (i, dateHorizonalCoordinate) in sortedDateHorizontalCoordinates.enumerated() {
            let coordinate = dateHorizonalCoordinate.horizontalCoordinate
            let point = pointAtHorizontalCoordinate(coordinate)
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        
        return path
    }

    var backgroundPath: Path {
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: radius,
            startAngle: Angle(degrees: 0),
            endAngle: Angle(degrees: 360),
            clockwise: true
        )
        path.closeSubpath()

        return path
    }

    var body: some View {
        backgroundPath
            .fill()
            .foregroundColor(.white)
            .overlay(
                backgroundPath
                    .stroke(Color.black, lineWidth: 1)
            )
            .overlay(
                pathFromSortedDateHorizontalCoordinates(sortedDateHorizontalCoordinates)
                    .stroke(Color.black, lineWidth: 1)
            )
    }
}

struct SkyChart_Previews: PreviewProvider {
    static let viewModel: SatelliteWidgetViewModel = {
        let tle = try! TLE(
            raw: """
            ISS (ZARYA)
            1 25544U 98067A   21150.17525219  .00001216  00000-0  30289-4 0  9997
            2 25544  51.6454  71.8132 0003443  45.7908  95.8066 15.48936547285805
            """
        )
        let sat = Satellite(withTLE: tle)

        let formatter = ISO8601DateFormatter()
        let date = formatter.date(from: "2021-06-02T20:35:30+0800")!

        return SatelliteWidgetViewModel(
            satelliteName: tle.commonName,
            sortedDateHorizontalCoordinates: (0..<75)
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
                sortedDateHorizontalCoordinates: viewModel.sortedDateHorizontalCoordinates
            )
        }
    }
}
