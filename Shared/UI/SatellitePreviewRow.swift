//
//  SatellitePreviewRow.swift
//  SatelliteForcast
//
//  Created by Ben Lu on 6/2/21.
//

import SwiftUI
import SatelliteKit
import SatelliteForcastCore
import SwiftSplines

struct SatelliteElevationCurve: View {
    /// The satellite to preview.
    var satellite: Satellite
    /// The observer coordinate in latitude (in degrees), longitude (in degrees) and altitude (in meters)
    var observerCoordinate: LatLonAlt
    var dateRange: Range<Date>
    var satellitePredictionInterval: TimeInterval = 20
    var timeGridLineInterval: TimeInterval = 30 * 60
    // Number of pixel per second
    var minimumHorizonalResolution: CGFloat = 3 / 60
    var elevationGridLineInterval: Double = 30

    var body: some View {
        let snapshots = satellite.snapshots(
            observer: observerCoordinate,
            dateRange: dateRange,
            interval: satellitePredictionInterval
        )
        GeometryReader { geometry in
            ScrollView(
                .horizontal,
                showsIndicators: false,
                content: {
                    let initialRect = geometry.frame(in: .local)
                    let widthPerSecond = initialRect.width / CGFloat(dateRange.upperBound.timeIntervalSince(dateRange.lowerBound))
                    let rect = CGRect(origin: initialRect.origin, size: CGSize(width: initialRect.width / widthPerSecond * max(widthPerSecond, minimumHorizonalResolution), height: initialRect.height))
                    Path { path in
                        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
                        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
                    }
                    .stroke(Color.black, lineWidth: 1)
                    .overlay(
                        ZStack {
                            let xDatePair: [(CGFloat, Date)] = {
                                let calendar = Calendar(identifier: .gregorian)
                                let components = calendar.dateComponents([.year, .month, .day, .hour], from: dateRange.lowerBound)
                                var date = calendar.date(from: components)!
                                var results = [(CGFloat, Date)]()
                                while true {
                                    defer {
                                        date.addTimeInterval(timeGridLineInterval)
                                    }
                                    if date < dateRange.lowerBound {
                                        continue
                                    }
                                    let xPercent = date.timeIntervalSince(dateRange.lowerBound) / (dateRange.upperBound.timeIntervalSince(dateRange.lowerBound))
                                    if xPercent < 0.05 {
                                        continue
                                    }
                                    if xPercent > 0.95 {
                                        break
                                    }

                                    let x = CGFloat(xPercent) * rect.width
                                    results.append((x, date))
                                }
                                return results
                            }()

                            Path { path in
                                for (x, _) in xDatePair {
                                    path.move(to: CGPoint(x: x, y: rect.minY))
                                    path.addLine(to: CGPoint(x: x, y: rect.maxY))
                                }
                            }
                            .stroke(Color.blue.opacity(0.5), lineWidth: 1)

                            let formatter: DateFormatter = {
                                let formatter = DateFormatter()
                                formatter.dateFormat = "HH:mm a"
                                return formatter
                            }()

                            ForEach(xDatePair, id: \.0) { (x, date) in
                                Text(formatter.string(from: date))
                                    .position(CGPoint(x: x, y: rect.maxY))
                            }
                        }
                    )
                    .overlay(
                        Path { path in
                            stride(from: -90.0, to: 90.0, by: elevationGridLineInterval).forEach { elev in
                                let y = CGFloat(elev + 90) / 180 * rect.height
                                path.move(to: CGPoint(x: rect.minX, y: y))
                                path.addLine(to: CGPoint(x: rect.maxX, y: y))
                            }
                        }
                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                    )
                    .overlay(
                        Path { path in
                            func snapshotPoint(_ snapshot: SatelliteSnapshot, i: Int) -> CGPoint {
                                let x = rect.width / CGFloat(snapshots.count) * CGFloat(i)
                                let y = CGFloat(snapshot.position.elev + 90) / 180 * -rect.height + rect.height
                                return CGPoint(x: x, y: y)
                            }
                            for (i, snapshot) in snapshots.enumerated() {
                                if i == 0 {
                                    path.move(to: snapshotPoint(snapshot, i: i))
                                } else {
                                    path.addLine(to: snapshotPoint(snapshot, i: i))
                                }
                            }
                        }
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue, Color.red]),
                                startPoint: .bottom,
                                endPoint: .top
                            ),
                            lineWidth: 1
                        )
                    )
                    .frame(
                        width: rect.width,
                        height: rect.height,
                        alignment: .center
                    )
                }
            )
            .frame(width: .infinity)
        }
    }
}

struct SatelliteElevationCurve_Previews: PreviewProvider {
    static var previews: some View {
        let tle = try! TLE(
            raw: """
            ISS (ZARYA)
            1 25544U 98067A   21152.11066515  .00000451  00000-0  16375-4 0  9992
            2 25544  51.6453  62.2423 0003364  52.3737  88.5313 15.48937685286109
            """
        )
        let sat = Satellite(withTLE: tle)
        SatelliteElevationCurve(
            satellite: sat,
            // 2000 Broadway, Redwood City, CA 94063
            observerCoordinate: LatLonAlt(lat: 37.486743000691185, lon: -122.22655970246515, alt: 0),
            dateRange: Date().advanced(by: -60 * 60 * 2)..<Date().advanced(by: 60 * 60 * 4)
        )
        .previewLayout(.fixed(width: 720, height: 240))
    }
}
