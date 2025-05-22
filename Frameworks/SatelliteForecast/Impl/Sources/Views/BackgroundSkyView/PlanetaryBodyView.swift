//
//  PlanetaryBodyView.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 6/21/21.
//

import Foundation
import SwiftUI
import SatelliteKit
import SatelliteForecast
import SolarSystem

struct PlanetaryBodyView: View {
    let planetaryBody: BackgroundSkyConfigs.PlantaryBody
    let label: BackgroundSkyConfigs.PlantaryBodyLabel
    let referenceDate: Double
    let observer: LatLonAlt
    let sunElevation: Double

    @ViewBuilder func planetView<Content: View>(
        solarSystemBody: SolarSystemBody,
        @ViewBuilder planetViewGenerator: @escaping (SolarSystemBody, AziEle) -> Content
    ) -> some View {
        let aziElev = solarSystemBody.aziEle(julianDay: referenceDate, observer: observer)

        if aziElev.elev >= 0 {
            GeometryReader { geometry in
                planetViewGenerator(solarSystemBody, aziElev)
            }
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let rect = geometry.frame(in: .local)

            if planetaryBody.visible(sunElevation: sunElevation) {
                planetView(
                    solarSystemBody: SolarSystemBody(planetaryBody)
                ) { solarSystemBody, coordinate in
                    planetaryBody.view(
                        label: label,
                        rect: rect
                    )
                    .position(
                        SkyChartUtils.point(
                            at: coordinate,
                            rect: rect
                        )
                    )
                }
            }
        }
    }
}

extension SolarSystemBody {
    init(_ planetaryBody: BackgroundSkyConfigs.PlantaryBody) {
        switch planetaryBody {
        case .sun: self = .sun
        case .moon: self = .moon
        case .mercury: self = .mercury
        case .venus: self = .venus
        case .mars: self = .mars
        case .jupiter: self = .jupiter
        case .saturn: self = .saturn
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
                .foregroundColor(Color("star", bundle: .module))
        }
    }

    fileprivate func visible(sunElevation: Double) -> Bool {
        switch self {
        case .sun, .moon:
            return true
        case .venus:
            return sunElevation < -6
        case .mercury, .jupiter, .mars, .saturn:
            return sunElevation < -12
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
            view(
                rect: rect,
                label: label,
                radius: 2,
                shapeModifier: PlanetsShapeModifier(),
                textLabel: {
                    Text("Mercury")
                        .font(.caption2)
                        .foregroundColor(.yellow)
                },
                symbol: {
                    Text("☿")
                        .font(.system(size: 5))
                        .foregroundColor(.white)
                }
            )
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
        case .mars:
            view(
                rect: rect,
                label: label,
                radius: 2,
                shapeModifier: PlanetsShapeModifier(),
                textLabel: {
                    Text("Mars")
                        .font(.caption2)
                        .foregroundColor(.red)
                },
                symbol: {
                    Text("♂")
                        .font(.system(size: 6))
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
