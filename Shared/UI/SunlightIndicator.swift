//
//  SunlightIndicator.swift
//  SatelliteForcast
//
//  Created by Ben Lu on 6/3/21.
//

import SwiftUI
import SatelliteKit
import SatelliteForcastCore
import BTree

struct SunlightIndicatorViewModel {
    fileprivate enum SunEvent: Identifiable {
        case rise
        case set

        var id: String {
            return String(describing: self)
        }

        fileprivate var imageName: String {
            switch self {
            case .rise:
                return "icon_sunrise"
            case .set:
                return "icon_sunset"
            }
        }

        fileprivate var systemImageName: String {
            switch self {
            case .rise:
                return "sunrise.fill"
            case .set:
                return "sunset.fill"
            }
        }
    }
    fileprivate let sunlightGradientStops: [Gradient.Stop]
    fileprivate let sunEventsXCoord: (CGRect) -> [(SunEvent, CGFloat)]

    init(
        snapshots: Map<Date, SatelliteSnapshot>,
        dateRange: Range<Date>
    ) {
        sunlightGradientStops = {
            guard let (_, firstSnapshot) = snapshots.first else {
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
                (-22, Color(.sRGB, red: 0 / 255, green: 3 / 255, blue: 61 / 255, opacity: 1)),
                (-90, Color(.sRGB, red: 0 / 255, green: 3 / 255, blue: 61 / 255, opacity: 1))
            ]

            func color(elevation: Double) -> Color {
                for i in 0..<boundaries.count - 1 {
                    if boundaries[i].0 >= elevation && boundaries[i + 1].0 < elevation {
                        return boundaries[i].1
                    }
                }
                fatalError("Elevation should between -90 and 90")
            }
            var stops = [Gradient.Stop]()
            stops.append(Gradient.Stop(color: color(elevation: firstSnapshot.sunElevation), location: 0))

            for index in snapshots.indices where index < snapshots.index(before: snapshots.endIndex) {
                let s1 = snapshots[index].1
                let s2 = snapshots[snapshots.index(after: index)].1

                let location: CGFloat = CGFloat(s1.date.timeIntervalSince(dateRange.lowerBound) / dateRange.upperBound.timeIntervalSince(dateRange.lowerBound))

                for (boundary, color) in boundaries {
                    if (s1.sunElevation > boundary && s2.sunElevation <= boundary) ||
                        (s1.sunElevation < boundary && s2.sunElevation >= boundary) {
                        stops.append(Gradient.Stop(color: color, location: location))
                    }
                }
            }

            stops.append(Gradient.Stop(color: color(elevation: snapshots.last!.1.sunElevation), location: 1))

            return stops
        }()

        let snapshotsSplitBySunriseOrSet = snapshots.split { s1, s2 in
            (s1.1.sunElevation > 0 && s2.1.sunElevation <= 0) ||
                (s1.1.sunElevation <= 0 && s2.1.sunElevation > 0)
        }

        let sunEventsXPercent: [(SunEvent, CGFloat)] = {
            if snapshotsSplitBySunriseOrSet.isEmpty {
                return []
            }
            var results = [(SunEvent, CGFloat)]()
            for i in 0..<snapshotsSplitBySunriseOrSet.count - 1 {
                let (s1, s2) = (snapshotsSplitBySunriseOrSet[i], snapshotsSplitBySunriseOrSet[i + 1])
                guard let (_, last) = s1.last, let (_, first) = s2.first else {
                    continue
                }
                if last.sunElevation <= 0 && first.sunElevation > 0 {
                    let percent = last.date.timeIntervalSince(dateRange.lowerBound) / dateRange.upperBound.timeIntervalSince(dateRange.lowerBound)
                    results.append((.rise, CGFloat(percent)))
                } else if last.sunElevation > 0 && first.sunElevation <= 0 {
                    let percent = last.date.timeIntervalSince(dateRange.lowerBound) / dateRange.upperBound.timeIntervalSince(dateRange.lowerBound)
                    results.append((.set, CGFloat(percent)))
                }
            }
            return results
        }()

        sunEventsXCoord = { rect in
            sunEventsXPercent.map { ($0.0, $0.1 * rect.width) }
        }
    }
}

struct SunlightIndicator: View {
    var viewModel: SunlightIndicatorViewModel

    /// A gradient colored indicator at the bottom to indicate sunlight at the observer's location.
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
            let rect = geometry.frame(in: .local)
            ZStack {
                sunlightIndicator

                ForEach(viewModel.sunEventsXCoord(rect), id: \.0) { (sunEvent, x) in
                    Image(systemName: sunEvent.systemImageName)
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(.white)
                        .frame(height: 18)
                        .position(x: x, y: rect.midY)
                }
            }
        }
    }
}


struct SunlightIndicator_Previews: PreviewProvider {
    static var previews: some View {
        let tle = try! TLE(
            raw: """
            ISS (ZARYA)
            1 25544U 98067A   21155.08058252  .00001489  00000-0  35252-4 0  9997
            2 25544  51.6446  47.5538 0003512  61.1482  91.5411 15.48950578286563
            """
        )
        let sat = Satellite(withTLE: tle)
        // 2000 Broadway, Redwood City, CA 94063
        let observerCoordinate = LatLonAlt(lat: 37.486743000691185, lon: -122.22655970246515, alt: 0)
        // Date range
        let dateRange = Date().advanced(by: -60 * 60 * 2)..<Date().advanced(by: 60 * 60 * 30)
        let viewModel = SunlightIndicatorViewModel(
            snapshots: sat.snapshots(
                observer: observerCoordinate,
                dateRange: dateRange,
                interval: 60
            ),
            dateRange: dateRange
        )
        SunlightIndicator(viewModel: viewModel)
            .previewLayout(.fixed(width: 320, height: 24))
    }
}
