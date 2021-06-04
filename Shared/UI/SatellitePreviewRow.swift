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
    // Generated data source
    fileprivate let satelliteElevationPath: (CGRect) -> CGPath
    fileprivate let unilluminatedPaths: (CGRect) -> CGPath
    fileprivate let xPercentDatePair: [(Double, Date, Int)]
    fileprivate let contentRect: (CGRect) -> CGRect

    // Copied properties
    fileprivate let snapshots: [SatelliteSnapshot]
    fileprivate let dateRange: Range<Date>
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
        self.snapshots = snapshots
        self.dateRange = dateRange
        self.elevationGridLineInterval = elevationGridLineInterval

        func snapshotPoint(_ snapshot: SatelliteSnapshot, i: Int, rect: CGRect) -> CGPoint {
            let x = rect.width / CGFloat(snapshots.count) * CGFloat(i)
            let y = CGFloat(snapshot.position.elev + 90) / 180 * -rect.height + rect.height
            return CGPoint(x: x, y: y)
        }

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
                if xPercent > 1 {
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
                    // Do not draw vertical lines that are too close to the edges
                    if x - rect.minX < 20 || rect.maxX - x < 20 {
                        continue
                    }
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

    /// An overlay on satellite elevation plot to indicate satellite in these ranges are not illuminated by the sun.
    private var satelliteDarknessPath: some View {
        GeometryReader { geometry in
            let rect = geometry.frame(in: .local)

            Path(viewModel.unilluminatedPaths(rect))
            .stroke(
                Color(white: 0.8),
                lineWidth: 2
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
                            .overlay(satelliteDarknessPath)

                        SunlightIndicator(
                            viewModel: SunlightIndicatorViewModel(
                                snapshots: viewModel.snapshots,
                                dateRange: viewModel.dateRange
                            )
                        )
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
            .previewDisplayName("ISS")

        let tle2 = try! TLE(
            raw: """
            DFH-1
            1 04382U 70034A   21154.78159189  .00001370  00000-0  21022-3 0  9993
            2 04382  68.4187 192.6131 1052892 188.4862 169.7083 13.08082975404634
            """
        )
        let sat2 = Satellite(withTLE: tle2)
        let viewModel2 = SatelliteElevationCurveViewModel(
            snapshots: sat2.snapshots(
                observer: observerCoordinate,
                dateRange: dateRange,
                interval: 20
            ),
            observerCoordinate: observerCoordinate,
            dateRange: dateRange
        )
        SatelliteElevationCurve(viewModel: viewModel2)
            .previewLayout(.fixed(width: 720, height: 240))
            .previewDisplayName("DFH-1")

        let tle3 = try! TLE(
            raw: """
            MOLNIYA 2-9
            1 07276U 74026A   21154.36625011 -.00000128  00000-0  00000-0 0  9990
            2 07276  64.2122 283.1177 6670908 285.3565  14.2908  2.45094844240000
            """
        )
        let sat3 = Satellite(withTLE: tle3)
        let viewModel3 = SatelliteElevationCurveViewModel(
            snapshots: sat3.snapshots(
                observer: observerCoordinate,
                dateRange: dateRange,
                interval: 20
            ),
            observerCoordinate: observerCoordinate,
            dateRange: dateRange
        )
        SatelliteElevationCurve(viewModel: viewModel3)
            .previewLayout(.fixed(width: 720, height: 240))
            .previewDisplayName("Molniya 2-9")

    }
}
