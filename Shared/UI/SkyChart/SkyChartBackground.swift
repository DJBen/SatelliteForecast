//
//  SkyChartBackground.swift
//  SkyChartBackground
//
//  Created by Ben Lu on 7/27/21.
//

import SwiftUI
import SatelliteKit

struct SkyChartBackgroundState: Equatable {
    var observer: LatLonAlt
}

struct SkyChartBackground: View {
    var state: SkyChartBackgroundState
    var configs: SkyChartConfigs

    @ViewBuilder var backgroundPath: some View {
        GeometryReader { geometry in
            let rect = geometry.frame(in: .local)
            Path { path in
                path.addArc(
                    center: CGPoint(x: rect.midX, y: rect.midY),
                    radius: SkyChart.radius(fromRect: rect),
                    startAngle: Angle(degrees: 0),
                    endAngle: Angle(degrees: 360),
                    clockwise: false
                )
                path.closeSubpath()
            }
            .stroke(Color("skyChartStroke"), lineWidth: 1)
        }
    }

    @ViewBuilder var azimuthMarks: some View {
        GeometryReader { geometry in
            let rect = geometry.frame(in: .local)
            Path { path in
                stride(from: 0, to: 360, by: configs.azimuthMarkInterval).forEach { azimuth in
                    let (point1, point2) = SkyChart.azimuthMarkPoints(
                        azimuth: Double(azimuth),
                        length: configs.azimuthMarkLength,
                        rect: rect
                    )
                    path.move(to: point1)
                    path.addLine(to: point2)
                }
            }
            .stroke(Color("skyChartStroke"), lineWidth: 1)
        }
    }

    @ViewBuilder var azimuthMarkTexts: some View {
        GeometryReader { geometry in
            let rect = geometry.frame(in: .local)
            let radius = SkyChart.radius(fromRect: rect)
            ZStack {
                if configs.showAzimuthTexts {
                    ForEach(
                        Array(stride(from: 0, to: 360, by: configs.azimuthMarkInterval)),
                        id: \.self,
                        content: { azimuth in
                            let angle: CGFloat = CGFloat(Double(azimuth + 180) * deg2rad)
                            Text("\(azimuth)°")
                                .font(.caption2)
                                .foregroundColor(.gray)
                                .position(x: rect.midX, y: rect.midY)
                                .rotationEffect(
                                    Angle(degrees: -(Double(angle) * rad2deg) + 180)
                                )
                                .offset(x: sin(angle) * (radius + 10), y: cos(angle) * (radius + 10))
                        }
                    )
                }
                let orientationAnglesNorth: [(String, Double, Double)] = [
                    ("NE", .pi * 0.75, -.pi * 0.5),
                    ("NW", .pi * -0.75, .pi * 0.5),
                    ("SE", .pi * 0.25, -.pi * 0.5),
                    ("SW", .pi * -0.25, .pi * 0.5)
                ]
                let orientationAnglesSouth: [(String, Double, Double)] = [
                    ("NE", .pi * -0.75, .pi * 0.5),
                    ("NW", .pi * 0.75, -.pi * 0.5),
                    ("SE", .pi * -0.25, .pi * 0.5),
                    ("SW", .pi * 0.25, -.pi * 0.5)
                ]
                let orientationAngles: [(String, Double, Double)] = state.observer.lon > 0 ? orientationAnglesNorth : orientationAnglesSouth
                if configs.showDirections {
                    ForEach(orientationAngles, id: \.self.0) { (direction, angle, textOrientation) in
                        Text(direction)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .position(x: rect.midX, y: rect.midY)
                            .rotationEffect(
                                Angle(degrees: (Double(angle + textOrientation) * rad2deg))
                            )
                            .offset(x: sin(CGFloat(angle)) * (radius + configs.directionTextOutset), y: cos(CGFloat(angle)) * (radius + configs.directionTextOutset))
                    }
                }
            }
        }
    }

    var body: some View {
        backgroundPath
            .overlay(azimuthMarks)
            .overlay(azimuthMarkTexts)
    }
}
