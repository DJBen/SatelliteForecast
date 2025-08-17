//
//  PlanetaryBodyView.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 6/21/21.
//

import Foundation
import SwiftUI
@preconcurrency import SatelliteKit
import SatelliteForecast
import SolarSystem

struct PlanetaryBodyView: View {
    let planetaryBody: SolarSystemBody
    let label: BackgroundSkyConfigs.PlantaryBodyLabel
    let magFunction: BackgroundSkyConfigs.StarMagToDisplayRadiusMappingFunction
    let referenceDate: Double
    let observer: LatLonAlt
    let sunElevation: Double

    var displayRadius: CGFloat {
        let apparentMagnitude = planetaryBody.apparentMagnitude(julianDay: referenceDate)
        return magFunction.apply(apparentMagnitude ?? 0)
    }

    @ViewBuilder func planetView<Content: View>(
        solarSystemBody: SolarSystemBody,
        @ViewBuilder planetViewGenerator: @escaping (SolarSystemBody, AziEle) -> Content
    ) -> some View {
        let aziElev = azel(
            time: Date(julianDate: referenceDate),
            site: LatLon(observer),
            cele: RADec(
                solarSystemBody.eci(
                    julianDay: referenceDate
                )
            )
        )

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
                    solarSystemBody: planetaryBody
                ) { solarSystemBody, coordinate in
                    planetaryBody.view(
                        label: label,
                        rect: rect,
                        radius: displayRadius
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
        case .uranus, .neptune:
            return sunElevation < -18
        case .earth, .earthMoonBarycenter:
            return false
        }
    }

    @ViewBuilder fileprivate func view(
        label: BackgroundSkyConfigs.PlantaryBodyLabel,
        rect: CGRect,
        radius: CGFloat
    ) -> some View {
        switch self {
        case .sun:
            view(
                rect: rect,
                label: label,
                radius: radius,
                shapeModifier: SunShapeModifier(),
                textLabel: {
                    Text("Sun", bundle: .module)
                        .font(.caption2)
                        .foregroundColor(.orange)
                },
                symbol: {
                    Text("☉", bundle: .module)
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                }
            )
        case .moon:
            view(
                rect: rect,
                label: label,
                radius: radius,
                shapeModifier: MoonShapeModifier(),
                textLabel: {
                    Text("Moon", bundle: .module)
                        .font(.caption2)
                        .foregroundColor(.blue)
                },
                symbol: {
                    Text("☾", bundle: .module)
                        .font(.system(size: 8))
                        .foregroundColor(.white)
                }
            )
        case .mercury:
            view(
                rect: rect,
                label: label,
                radius: radius,
                shapeModifier: PlanetsShapeModifier(),
                textLabel: {
                    Text("Mercury", bundle: .module)
                        .font(.caption2)
                        .foregroundColor(.yellow)
                },
                symbol: {
                    Text("☿", bundle: .module)
                        .font(.system(size: 5))
                        .foregroundColor(.white)
                }
            )
        case .venus:
            view(
                rect: rect,
                label: label,
                radius: radius,
                shapeModifier: PlanetsShapeModifier(),
                textLabel: {
                    Text("Venus", bundle: .module)
                        .font(.caption2)
                        .foregroundColor(.orange)
                },
                symbol: {
                    Text("♀", bundle: .module)
                        .font(.system(size: 7))
                        .foregroundColor(.white)
                }
            )
        case .mars:
            view(
                rect: rect,
                label: label,
                radius: radius,
                shapeModifier: PlanetsShapeModifier(),
                textLabel: {
                    Text("Mars", bundle: .module)
                        .font(.caption2)
                        .foregroundColor(.red)
                },
                symbol: {
                    Text("♂", bundle: .module)
                        .font(.system(size: 6))
                        .foregroundColor(.white)
                }
            )
        case .jupiter:
            view(
                rect: rect,
                label: label,
                radius: radius,
                shapeModifier: PlanetsShapeModifier(),
                textLabel: {
                    Text("Jupiter", bundle: .module)
                        .font(.caption2)
                        .foregroundColor(.pink)
                },
                symbol: {
                    Text("♃", bundle: .module)
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
                    Text("Saturn", bundle: .module)
                        .font(.caption2)
                        .foregroundColor(.purple)
                },
                symbol: {
                    Text("♄", bundle: .module)
                        .font(.system(size: 4))
                        .foregroundColor(.white)
                }
            )
        case .earth, .earthMoonBarycenter:
            // Not applied
            EmptyView()
        case .uranus:
            // TODO
            EmptyView()
        case .neptune:
            // TODO
            EmptyView()
        }
    }
}
