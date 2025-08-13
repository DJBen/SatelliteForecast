//
//  SunlightIndicator.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 6/3/21.
//

import SwiftUI
@preconcurrency import SatelliteKit
import SatelliteForecast
import BTree
import SolarSystem

struct SunlightIndicatorViewModel: Equatable {
    enum SunEvent: Equatable, Hashable {
        case rise
        case set

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

    struct SunEventXCoord: Hashable, Identifiable {
        let sunEvent: SunEvent
        let xCoord: CGFloat

        var id: String {
            return String(describing: self)
        }
    }

    let sunlightGradientStops: [Gradient.Stop]
    let sunEventsXPercent: [SunEventXCoord]

    init(
        julianDateElevations: [Double: Double]
    ) {
        let keys = julianDateElevations.keys.sorted(by: <)

        sunlightGradientStops = {
            guard let startDate = keys.first,
                  let endDate = keys.last else {
                return []
            }
            let firstElevation = julianDateElevations[startDate]!
            let lastElevation = julianDateElevations[endDate]!

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

            for (index, key) in keys.enumerated() where index < keys.count - 1 {
                let (d1, e1) = (key, julianDateElevations[key]!)
                let e2 = julianDateElevations[keys[index + 1]]!

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

        let jdElevationPairs = keys.map { ($0, julianDateElevations[$0]!) }

        let jdElevationsSplitBySunriseOrSet = jdElevationPairs.split { s1, s2 in
            (s1.1 > 0 && s2.1 <= 0) ||
                (s1.1 <= 0 && s2.1 > 0)
        }

        sunEventsXPercent = {
            guard let (startDate, _) = jdElevationPairs.first,
                  let (endDate, _) = jdElevationPairs.last else {
                return []
            }

            var results = [SunEventXCoord]()
            for i in 0..<jdElevationsSplitBySunriseOrSet.count - 1 {
                let (s1, s2) = (jdElevationsSplitBySunriseOrSet[i], jdElevationsSplitBySunriseOrSet[i + 1])
                guard let (prevDate, prevElev) = s1.last, let (_, nextElev) = s2.first else {
                    continue
                }
                if prevElev <= 0 && nextElev > 0 {
                    let percent = (prevDate - startDate) / (endDate - startDate)
                    results.append(SunEventXCoord(sunEvent: .rise, xCoord: CGFloat(percent)))
                } else if prevElev > 0 && nextElev <= 0 {
                    let percent = (prevDate - startDate) / (endDate - startDate)
                    results.append(SunEventXCoord(sunEvent: .set, xCoord: CGFloat(percent)))
                }
            }
            return results
        }()
    }
}

struct SunlightIndicator: View, Equatable {
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
    
    /// An efficient function to map dense satellite snapshots over a date range to a julian date -> sun elevation map.
    /// - Parameter snapshots: The snapshots.
    /// - Returns: A tree mapping from JD -> sun elevations.
    static func sunElevations(julianDateRange: ClosedRange<Double>, observer: LatLonAlt) -> [Double: Double] {
        var julianDateElevations = [Double: Double]()
        
        // Stride in a 10 minute interval across the julian date to improve performance
        for julianDate in stride(from: julianDateRange.lowerBound.roundJulianDate(.toMins(10)), through: julianDateRange.upperBound.roundJulianDate(.toMins(10)), by: 10 * TimeConstants.min2day) {
            julianDateElevations[julianDate] = azel(
                time: Date(julianDate: julianDate),
                site: LatLon(observer),
                cele: RADec(
                    SolarSystemBody.sun.eci(
                        julianDay: julianDate
                    )
                )
            ).elev
        }

        return julianDateElevations
    }

    private func sunEventsXCoord(rect: CGRect) -> [SunlightIndicatorViewModel.SunEventXCoord] {
        viewModel.sunEventsXPercent.map {
            SunlightIndicatorViewModel.SunEventXCoord(sunEvent: $0.sunEvent, xCoord: $0.xCoord * rect.width)
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let rect = geometry.frame(in: .local)
            ZStack {
                sunlightIndicator

                ForEach(sunEventsXCoord(rect: rect)) { sunEventXCoord in
                    Image(systemName: sunEventXCoord.sunEvent.systemImageName)
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(.white)
                        .frame(height: 18)
                        .position(x: sunEventXCoord.xCoord, y: rect.midY)
                }
            }
        }
    }
}

#if DEBUG
struct SunlightIndicator_Previews: PreviewProvider {
    static var previews: some View {
        // 2000 Broadway, Redwood City, CA 94063
        let observerCoordinate = LatLonAlt(37.486743000691185, -122.22655970246515, 0)
        // Date range
        let julianDateRange = Date().advanced(by: -60 * 60 * 2).julianDate...Date().advanced(by: 60 * 60 * 30).julianDate
        let jdElevs = SunlightIndicator.sunElevations(julianDateRange: julianDateRange, observer: observerCoordinate)
        let viewModel = SunlightIndicatorViewModel(
            julianDateElevations: jdElevs
        )
        SunlightIndicator(viewModel: viewModel)
            .previewLayout(.fixed(width: 320, height: 24))
    }
}
#endif
