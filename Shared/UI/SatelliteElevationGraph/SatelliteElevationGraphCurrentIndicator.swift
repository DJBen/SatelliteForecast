//
//  SatelliteElevationGraphCurrentIndicator.swift
//  SatelliteForcast
//
//  Created by Ben Lu on 7/23/21.
//

import SwiftUI

struct SatelliteElevationGraphCurrentIndicator: View {
    let percentageCoordinate: CGPoint

    @State private var scale: CGFloat = 1
    @State private var opacity: Double = 1

    private var repeatingAnimation: Animation {
        Animation
            .easeInOut(duration: 3)
            .repeatForever(autoreverses: false)
    }

    var body: some View {
        GeometryReader { geometry in
            let rect = geometry.frame(in: .local)

            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: rect.maxX * percentageCoordinate.x, y: 0))
                    path.addLine(to: CGPoint(x: rect.maxX * percentageCoordinate.x, y: rect.maxY))
                }
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [2]))
                .foregroundColor(.blue)

                Group {
                    Circle(
                    )
                    .frame(width: 14, height: 14)
                    .foregroundColor(.blue)

                    Circle(
                    )
                    .frame(width: 14, height: 14)
                    .foregroundColor(.blue)
                    .scaleEffect(scale)
                    .opacity(opacity)
                    .onAppear {
                        withAnimation(repeatingAnimation) {
                            self.scale = 2
                            self.opacity = 0
                        }
                    }

                    Circle(
                    )
                    .frame(width: 10, height: 10)
                    .foregroundColor(.white)
                }
                .position(x: rect.maxX * percentageCoordinate.x, y: rect.maxY * percentageCoordinate.y)
            }
        }
    }
}

struct SatelliteElevationGraphCurrentIndicator_Previews: PreviewProvider {
    static var previews: some View {
        SatelliteElevationGraphCurrentIndicator(percentageCoordinate: CGPoint(x: 0.3, y: 0.3))
            .frame(width: 100, height: 100)
            .previewLayout(.fixed(width: 100, height: 100))
    }
}
