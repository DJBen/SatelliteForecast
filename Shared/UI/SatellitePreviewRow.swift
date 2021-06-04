//
//  SatellitePreviewRow.swift
//  SatelliteForcast
//
//  Created by Ben Lu on 6/2/21.
//

import SwiftUI
import SatelliteKit
import SatelliteForcastCore

struct SatelliteElevationCurveViewModel {
    // Data source
    fileprivate let satelliteElevationPath: (CGRect) -> CGPath
    fileprivate let unilluminatedPaths: (CGRect) -> CGPath
    fileprivate let xPercentDatePair: [(Double, Date, Int)]
    fileprivate let sunlightGradientStops: [Gradient.Stop]
    fileprivate let contentRect: (CGRect) -> CGRect

    fileprivate let elevationGridLineInterval: Double

    /// Initialize the view model.
    /// - Parameters:
    ///   - snapshots: Satellite snapshots.
    ///   - observerCoordinate: The observer coordinate in latitude (in degrees), longitude (in degrees) and altitude (in meters)
    ///   - dateRange: The date range
    init(
        snapshots: [SatelliteSnapshot],
        observerCoordinate: LatLonAlt,
        dateRange: Range<Date>,
        timeGridLineInterval: TimeInterval = 30 * 60,
        // Horizontal width per second
        minimumHorizonalResolution: CGFloat = 3 / 60,
        elevationGridLineInterval: Double = 30
    ) {
        func snapshotPoint(_ snapshot: SatelliteSnapshot, i: Int, rect: CGRect) -> CGPoint {
            let x = rect.width / CGFloat(snapshots.count) * CGFloat(i)
            let y = CGFloat(snapshot.position.elev + 90) / 180 * -rect.height + rect.height
            return CGPoint(x: x, y: y)
        }

        self.elevationGridLineInterval = elevationGridLineInterval

        satelliteElevationPath = { rect in
            let path = CGMutablePath()
            for (i, snapshot) in snapshots.enumerated() {
                if i == 0 {
                    path.move(to: snapshotPoint(snapshot, i: i, rect: rect))
                } else {
                    path.addLine(to: snapshotPoint(snapshot, i: i, rect: rect))
                }
            }
            return path.copy()!
        }

        let snapshotsSplitByIllumination = Array(snapshots.enumerated())
            .split { (s1, s2) -> Bool in
            return s1.1.isIlluminated == s2.1.isIlluminated
        }

        unilluminatedPaths = { rect in
            let path = CGMutablePath()
            snapshotsSplitByIllumination
                .filter { !($0.first?.1.isIlluminated ?? true) }
                .forEach { snapshots in
                    for (i, s) in snapshots.enumerated() {
                        let (globalIndex, snapshot) = s
                        if i == 0 {
                            path.move(to: snapshotPoint(snapshot, i: globalIndex, rect: rect))
                        } else {
                            path.addLine(to: snapshotPoint(snapshot, i: globalIndex, rect: rect))
                        }
                    }
                }
            return path.copy()!
        }

        sunlightGradientStops = {
            guard let firstSnapshot = snapshots.first else {
                return []
            }

            let boundaries: [(Double, Color)] = [
                (90, Color(.sRGB, red: 255 / 255, green: 250 / 255, blue: 240 / 255, opacity: 1)),
                (50, Color(.sRGB, red: 255 / 255, green: 240 / 255, blue: 233 / 255, opacity: 1)),
                (30, Color(.sRGB, red: 255 / 255, green: 219 / 255, blue: 186 / 255, opacity: 1)),
                (10, Color(.sRGB, red: 255 / 255, green: 196 / 255, blue: 137 / 255, opacity: 1)),
                (0, Color(.sRGB, red: 237 / 255, green: 109 / 255, blue: 83 / 255, opacity: 1)),
                (-6, Color(.sRGB, red: 190 / 255, green: 74 / 255, blue: 210 / 255, opacity: 1)),
                (-12, Color(.sRGB, red: 119 / 255, green: 34 / 255, blue: 194 / 255, opacity: 1)),
                (-18, Color(.sRGB, red: 42 / 255, green: 42 / 255, blue: 136 / 255, opacity: 1)),
                (-22, Color(.sRGB, red: 0 / 255, green: 3 / 255, blue: 61 / 255, opacity: 1))
            ]

            func color(elevation: Double) -> Color {
                return boundaries.first { $0.0 >= elevation }!.1
            }
            var stops = [Gradient.Stop]()
            stops.append(Gradient.Stop(color: color(elevation: firstSnapshot.sunElevation), location: 0))

            for i in (0..<snapshots.count - 1) {
                let (s1, s2) = (snapshots[i], snapshots[i + 1])
                let location: CGFloat = CGFloat(i) / CGFloat(snapshots.count)

                for (boundary, color) in boundaries {
                    if (s1.sunElevation > boundary && s2.sunElevation <= boundary) ||
                        (s1.sunElevation < boundary && s2.sunElevation >= boundary) {
                        stops.append(Gradient.Stop(color: color, location: location))
                    }
                }
            }

            stops.append(Gradient.Stop(color: color(elevation: snapshots.last!.sunElevation), location: 1))

            return stops
        }()

        xPercentDatePair = {
            let calendar = Calendar(identifier: .gregorian)
            let components = calendar.dateComponents([.year, .month, .day, .hour], from: dateRange.lowerBound)
            var date = calendar.date(from: components)!
            var results = [(Double, Date, Int)]()
            var index: Int = 0
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
                results.append((xPercent, date, index))
                index += 1
            }
            return results
        }()

        contentRect = { initialRect in
            let widthPerSecond = initialRect.width / CGFloat(dateRange.upperBound.timeIntervalSince(dateRange.lowerBound))
            return CGRect(origin: initialRect.origin, size: CGSize(width: initialRect.width / widthPerSecond * max(widthPerSecond, minimumHorizonalResolution), height: initialRect.height))
        }
    }
}

struct SatelliteElevationCurve: View {
    var viewModel: SatelliteElevationCurveViewModel

    private var timeGrid: some View {
        GeometryReader { geometry in
            let rect = geometry.frame(in: .local)

            Path { path in
                for (xPercent, _, _) in viewModel.xPercentDatePair {
                    let x = CGFloat(xPercent) * rect.width
                    path.move(to: CGPoint(x: x, y: rect.minY))
                    path.addLine(to: CGPoint(x: x, y: rect.maxY))
                }
            }
            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        }
    }

    private var elevationGrid: some View {
        GeometryReader { geometry in
            let rect = geometry.frame(in: .local)
            let elevIterator = stride(from: -90.0, to: 90.0, by: viewModel.elevationGridLineInterval)
            ZStack {
                Path { path in
                    elevIterator.forEach { elev in
                        let y = CGFloat(elev + 90) / 180 * rect.height
                        path.move(to: CGPoint(x: rect.minX, y: y))
                        path.addLine(to: CGPoint(x: rect.maxX, y: y))
                    }
                }
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)

                Path { path in
                    path.move(to: CGPoint(x: rect.minX, y: rect.midY))
                    path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
                }
                .stroke(Color.gray, lineWidth: 1)

                ForEach(Array(elevIterator), id: \.self) { elev in
                    let y = CGFloat(elev + 90) / 180 * rect.height

                    Text("\(Int(-elev))º")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .frame(height: 30, alignment: .bottomTrailing)
                        .position(x: 15, y: y)
                }
            }
        }
    }

    private var satelliteElevationPlot: some View {
        GeometryReader { geometry in
            let rect = geometry.frame(in: .local)

            Path(viewModel.satelliteElevationPath(rect))
            .stroke(
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue, Color.red]),
                    startPoint: .bottom,
                    endPoint: .top
                ),
                lineWidth: 2
            )
        }
    }

    private var illuminationIndicator: some View {
        GeometryReader { geometry in
            let rect = geometry.frame(in: .local)

            Path(viewModel.unilluminatedPaths(rect))
            .stroke(
                Color(white: 0.8),
                lineWidth: 2
            )
        }
    }

    private var sunlightIndicator: some View {
        GeometryReader { geometry in
            let rect = geometry.frame(in: .local)

            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(stops: viewModel.sunlightGradientStops),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(
                    width: rect.width,
                    height: rect.height
                )
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let formatter: DateFormatter = {
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm a"
                return formatter
            }()

            let initialRect = geometry.frame(in: .local)
            let rect = viewModel.contentRect(initialRect)

            ScrollView(
                .horizontal,
                showsIndicators: false,
                content: {
                    VStack(
                        alignment: .leading,
                        spacing: 4
                    ) {
                        timeGrid
                            .overlay(elevationGrid)
                            .overlay(satelliteElevationPlot)
                            .overlay(illuminationIndicator)

                        sunlightIndicator
                            .frame(height: 24)

                        HStack(alignment: .center, spacing: 0) {
                            ForEach(viewModel.xPercentDatePair, id: \.0) { (xPercent, date, index) in
                                VStack {
                                    Text(
                                        formatter.string(from: date)
                                    )
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .frame(width: 80)
                                    .offset(x: CGFloat(xPercent) * rect.width - CGFloat(index) * 80 - 40)
                                }
                            }
                        }
                    }
                    .frame(
                        width: rect.width,
                        height: rect.height,
                        alignment: .leading
                    )
                }
            )
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
        // 2000 Broadway, Redwood City, CA 94063
        let observerCoordinate = LatLonAlt(lat: 37.486743000691185, lon: -122.22655970246515, alt: 0)
        // Date range
        let dateRange = Date().advanced(by: -60 * 60 * 2)..<Date().advanced(by: 60 * 60 * 4)
        let viewModel = SatelliteElevationCurveViewModel(
            snapshots: sat.snapshots(
                observer: observerCoordinate,
                dateRange: dateRange,
                interval: 20
            ),
            observerCoordinate: observerCoordinate,
            dateRange: dateRange
        )
        SatelliteElevationCurve(viewModel: viewModel)
            .previewLayout(.fixed(width: 720, height: 240))
    }
}
