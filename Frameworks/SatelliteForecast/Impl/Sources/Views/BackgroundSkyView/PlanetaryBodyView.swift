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
        // Sun and Moon are resolved disks, independent of point-source photometry.
        if planetaryBody == .sun || planetaryBody == .moon { return 12 }
        let apparentMagnitude = planetaryBody.apparentMagnitude(julianDay: referenceDate)
        return magFunction.apply(apparentMagnitude ?? 0)
    }

    @ViewBuilder func planetView<Content: View>(
        solarSystemBody: SolarSystemBody,
        @ViewBuilder planetViewGenerator: @escaping (SolarSystemBody, AziEle) -> Content
    ) -> some View {
        let aziElev = solarSystemBody == .moon
            ? MoonAppearance.coordinate(julianDate: referenceDate, observer: observer)
            : azel(
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
                    let labelOnLeft = SkyChartUtils.point(at: coordinate, rect: rect).x > rect.midX
                    if planetaryBody == .moon {
                        MoonDiskView(julianDate: referenceDate, observer: observer, radius: displayRadius, chartRect: rect)
                            .overlay(alignment: labelOnLeft ? .trailing : .leading) {
                                if label == .text {
                                    Text("Moon", bundle: .module)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .fixedSize()
                                        .offset(x: (labelOnLeft ? -1 : 1) * (displayRadius * 2 + 3))
                                }
                            }
                            .position(SkyChartUtils.point(at: coordinate, rect: rect))
                    } else {
                        planetaryBody.view(label: label, rect: rect, radius: displayRadius, labelOnLeft: labelOnLeft, magnitude: planetaryBody.apparentMagnitude(julianDay: referenceDate) ?? 0)
                            .position(SkyChartUtils.point(at: coordinate, rect: rect))
                    }
                }
            }
        }
    }
}

extension SolarSystemBody {
    @ViewBuilder private func view<TextLabel: View, Symbol: View> (
        rect: CGRect,
        label: BackgroundSkyConfigs.PlantaryBodyLabel,
        radius: CGFloat,
        labelOnLeft: Bool,
        magnitude: Double,
        @ViewBuilder textLabel: () -> TextLabel,
        @ViewBuilder symbol: () -> Symbol
    ) -> some View {

        let path = Canvas { context, size in
            context.withCGContext { cg in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                if self == .sun {
                    cg.setFillColor(UIColor(red: 1, green: 0.97, blue: 0.84, alpha: 1).cgColor)
                    cg.setShadow(offset: .zero, blur: 12, color: UIColor.orange.withAlphaComponent(0.8).cgColor)
                    cg.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
                } else {
                    SkyChartTheme.drawPointSource(in: cg, at: center, radius: radius,
                        color: UIColor(named: "star", in: .module, compatibleWith: nil)!, magnitude: magnitude)
                }
            }
        }
        .frame(width: radius * 4, height: radius * 4)


        path.overlay(alignment: labelOnLeft ? .trailing : .leading) {
            switch label {
            case .text:
                textLabel().fixedSize().offset(x: (labelOnLeft ? -1 : 1) * (radius * 3 + 3))
            case .symbol:
                // Compact charts already show recognizable Sun and Moon disks.
                // A second symbol beside a disk looks like another celestial object.
                if self != .sun && self != .moon {
                    symbol().fixedSize().offset(x: (labelOnLeft ? -1 : 1) * (radius * 3 + 2))
                }
            }
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
        radius: CGFloat,
        labelOnLeft: Bool,
        magnitude: Double
    ) -> some View {
        switch self {
        case .sun:
            view(
                rect: rect,
                label: label,
                radius: radius,
                labelOnLeft: labelOnLeft,
                magnitude: magnitude,
                textLabel: {
                    Text("Sun", bundle: .module)
                        .font(.caption2)
                        .foregroundColor(.orange)
                },
                symbol: {
                    Text(verbatim: "☉")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                }
            )
        case .moon:
            // The observer-aware textured Moon is rendered by PlanetaryBodyView.
            EmptyView()
        case .mercury:
            view(
                rect: rect,
                label: label,
                radius: radius,
                labelOnLeft: labelOnLeft,
                magnitude: magnitude,
                textLabel: {
                    Text("Mercury", bundle: .module)
                        .font(.caption2)
                        .foregroundColor(.yellow)
                },
                symbol: {
                    Text(verbatim: "☿")
                        .font(.system(size: 9))
                        .foregroundColor(.white)
                }
            )
        case .venus:
            view(
                rect: rect,
                label: label,
                radius: radius,
                labelOnLeft: labelOnLeft,
                magnitude: magnitude,
                textLabel: {
                    Text("Venus", bundle: .module)
                        .font(.caption2)
                        .foregroundColor(.orange)
                },
                symbol: {
                    Text(verbatim: "♀")
                        .font(.system(size: 9))
                        .foregroundColor(.white)
                }
            )
        case .mars:
            view(
                rect: rect,
                label: label,
                radius: radius,
                labelOnLeft: labelOnLeft,
                magnitude: magnitude,
                textLabel: {
                    Text("Mars", bundle: .module)
                        .font(.caption2)
                        .foregroundColor(.red)
                },
                symbol: {
                    Text(verbatim: "♂")
                        .font(.system(size: 9))
                        .foregroundColor(.white)
                }
            )
        case .jupiter:
            view(
                rect: rect,
                label: label,
                radius: radius,
                labelOnLeft: labelOnLeft,
                magnitude: magnitude,
                textLabel: {
                    Text("Jupiter", bundle: .module)
                        .font(.caption2)
                        .foregroundColor(.pink)
                },
                symbol: {
                    Text(verbatim: "♃")
                        .font(.system(size: 9))
                        .foregroundColor(.white)
                }
            )
        case .saturn:
            view(
                rect: rect,
                label: label,
                radius: radius,
                labelOnLeft: labelOnLeft,
                magnitude: magnitude,
                textLabel: {
                    Text("Saturn", bundle: .module)
                        .font(.caption2)
                        .foregroundColor(.purple)
                },
                symbol: {
                    Text(verbatim: "♄")
                        .font(.system(size: 9))
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
