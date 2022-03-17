//
//  PlanetaryBodyView.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/21/21.
//

import Foundation
import SwiftUI
import SatelliteKit

struct PlanetaryBodyView: View {
    let planetaryBody: BackgroundSkyConfigs.PlantaryBody
    let label: BackgroundSkyConfigs.PlantaryBodyLabel
    let referenceDate: Double
    let observer: LatLonAlt
    let sunElevation: Double

    @ViewBuilder func planetView<Content: View>(
        celestialCoordinateProvider: (Double) -> RADec,
        @ViewBuilder planetViewGenerator: @escaping (AziEleDst) -> Content
    ) -> some View {
        let (alt, azi) = azel(
            julianDate: referenceDate,
            site: (observer.lat, observer.lon),
            cele: celestialCoordinateProvider(referenceDate)
        )
        let planetCoordinate = AziEleDst(azim: azi, elev: alt, dist: 0)

        if planetCoordinate.elev >= 0 {
            GeometryReader { geometry in
                planetViewGenerator(planetCoordinate)
            }
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let rect = geometry.frame(in: .local)

            if let celestialCoordinateProvider = planetaryBody.celestialCoordinateProvider, planetaryBody.visible(sunElevation: sunElevation) {
                planetView(
                    celestialCoordinateProvider: celestialCoordinateProvider
                ) { observer in
                    planetaryBody.view(
                        label: label,
                        rect: rect
                    )
                    .position(
                        SkyChart.point(
                            at: observer,
                            rect: rect
                        )
                    )
                }
            }
        }
    }
}


extension BackgroundSkyConfigs.PlantaryBody {
    @ViewBuilder private func view<ShapeModifier: ViewModifier, TextLabel: View, Symbol: View> (
        rect: CGRect,
        label: BackgroundSkyConfigs.PlantaryBodyLabel,
        radius: CGFloat,
        shapeModifier: ShapeModifier,
        @ViewBuilder textLabel: () -> TextLabel,
        @ViewBuilder symbol: () -> Symbol
    ) -> some View {

        let path = Path { path in
            path.addArc(
                center: CGPoint(x: rect.midX, y: rect.midY),
                radius: radius,
                startAngle: Angle(degrees: 0),
                endAngle: Angle(degrees: 360),
                clockwise: false
            )
        }
        .fill()
        .modifier(shapeModifier)

        switch label {
        case .text:
            HStack(spacing: 0) {
                path
                textLabel(
                )
                .offset(x: radius + 2)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

        case .symbol:
            ZStack {
                path
                symbol(
                )
                .frame(alignment: .center)
            }
        }
    }

    private struct SunShapeModifier: ViewModifier {
        func body(content: Content) -> some View {
            content
                .foregroundColor(.yellow)
                .shadow(color: .yellow, radius: 12, x: 0.0, y: 0.0)
        }
    }

    private struct MoonShapeModifier: ViewModifier {
        func body(content: Content) -> some View {
            content
                .foregroundColor(.gray)
                .shadow(color: .yellow.opacity(0.7), radius: 8, x: 0.0, y: 0.0)
        }
    }

    private struct PlanetsShapeModifier: ViewModifier {
        func body(content: Content) -> some View {
            content
                .foregroundColor(Color("star"))
        }
    }

    fileprivate var celestialCoordinateProvider: ((Double) -> RADec)? {
        switch self {
        case .sun:
            return solarGeo(julianDays:)
        case .moon:
            return lunarGeo(julianDays:)
        case .venus, .jupiter, .saturn, .mercury:
            return nil
        }
    }

    fileprivate func visible(sunElevation: Double) -> Bool {
        switch self {
        case .sun, .moon:
            return true
        case .venus:
            return sunElevation > -6
        case .mercury, .jupiter:
            return sunElevation > -12
        case .saturn:
            return sunElevation > -16
        }
    }

    @ViewBuilder fileprivate func view(
        label: BackgroundSkyConfigs.PlantaryBodyLabel,
        rect: CGRect
    ) -> some View {
        switch self {
        case .sun:
            view(
                rect: rect,
                label: label,
                radius: 8,
                shapeModifier: SunShapeModifier(),
                textLabel: {
                    Text("Sun")
                        .font(.caption2)
                        .foregroundColor(.orange)
                },
                symbol: {
                    Text("☉")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                }
            )
        case .moon:
            view(
                rect: rect,
                label: label,
                radius: 5,
                shapeModifier: MoonShapeModifier(),
                textLabel: {
                    Text("Moon")
                        .font(.caption2)
                        .foregroundColor(.blue)
                },
                symbol: {
                    Text("☾")
                        .font(.system(size: 8))
                        .foregroundColor(.white)
                }
            )
        case .mercury:
            // Hides mercury for now
            EmptyView()
        case .venus:
            view(
                rect: rect,
                label: label,
                radius: 3.5,
                shapeModifier: PlanetsShapeModifier(),
                textLabel: {
                    Text("Venus")
                        .font(.caption2)
                        .foregroundColor(.orange)
                },
                symbol: {
                    Text("♀")
                        .font(.system(size: 7))
                        .foregroundColor(.white)
                }
            )
        case .jupiter:
            view(
                rect: rect,
                label: label,
                radius: 3,
                shapeModifier: PlanetsShapeModifier(),
                textLabel: {
                    Text("Jupiter")
                        .font(.caption2)
                        .foregroundColor(.pink)
                },
                symbol: {
                    Text("♃")
                        .font(.system(size: 6))
                        .foregroundColor(.white)
                }
            )
        case .saturn:
            view(
                rect: rect,
                label: label,
                radius: 2,
                shapeModifier: PlanetsShapeModifier(),
                textLabel: {
                    Text("Saturn")
                        .font(.caption2)
                        .foregroundColor(.purple)
                },
                symbol: {
                    Text("♄")
                        .font(.system(size: 4))
                        .foregroundColor(.white)
                }
            )
        }
    }
}
