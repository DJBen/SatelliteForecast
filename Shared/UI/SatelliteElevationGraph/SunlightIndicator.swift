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
        julianDateElevations: Map<Double, Double>
    ) {
        sunlightGradientStops = {
            guard let (startDate, firstElevation) = julianDateElevations.first,
                  let (endDate, lastElevation) = julianDateElevations.last else {
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
            stops.append(Gradient.Stop(color: color(elevation: firstElevation), location: 0))

            for index in julianDateElevations.indices where index < julianDateElevations.index(before: julianDateElevations.endIndex) {
                let (d1, e1) = julianDateElevations[index]
                let e2 = julianDateElevations[julianDateElevations.index(after: index)].1

                let location: CGFloat = CGFloat((d1 - startDate) / (endDate - startDate))

                for (boundary, color) in boundaries {
                    if (e1 > boundary && e2 <= boundary) ||
                        (e1 < boundary && e2 >= boundary) {
                        stops.append(Gradient.Stop(color: color, location: location))
                    }
                }
            }

            stops.append(Gradient.Stop(color: color(elevation: lastElevation), location: 1))

            return stops
        }()

        let jdElevationsSplitBySunriseOrSet = julianDateElevations.split { s1, s2 in
            (s1.1 > 0 && s2.1 <= 0) ||
                (s1.1 <= 0 && s2.1 > 0)
        }

        let sunEventsXPercent: [(SunEvent, CGFloat)] = {
            guard let (startDate, _) = julianDateElevations.first,
                  let (endDate, _) = julianDateElevations.last else {
                return []
            }

            var results = [(SunEvent, CGFloat)]()
            for i in 0..<jdElevationsSplitBySunriseOrSet.count - 1 {
                let (s1, s2) = (jdElevationsSplitBySunriseOrSet[i], jdElevationsSplitBySunriseOrSet[i + 1])
                guard let (prevDate, prevElev) = s1.last, let (_, nextElev) = s2.first else {
                    continue
                }
                if prevElev <= 0 && nextElev > 0 {
                    let percent = (prevDate - startDate) / (endDate - startDate)
                    results.append((.rise, CGFloat(percent)))
                } else if prevElev > 0 && nextElev <= 0 {
                    let percent = (prevDate - startDate) / (endDate - startDate)
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

#if DEBUG
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
        let julianDateRange = Date().advanced(by: -60 * 60 * 2).julianDate..<Date().advanced(by: 60 * 60 * 30).julianDate

        let jdElevs = sat.snapshots(
            observer: observerCoordinate,
            julianDateRange: julianDateRange,
            interval: 60
        )
        .map { ($0, $1.sunElevation) }
        .reduce(into: Map<Double, Double>(), { $0[$1.0] = $1.1 })
        let viewModel = SunlightIndicatorViewModel(
            julianDateElevations: jdElevs
        )
        SunlightIndicator(viewModel: viewModel)
            .previewLayout(.fixed(width: 320, height: 24))
    }
}
#endif
