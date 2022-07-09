//
//  ChartRendering.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 4/9/22.
//

import SatelliteKit
import StarryNight

public struct SatellitePassPathRenderParams: Equatable {
    public var rect: CGRect
    public var snapshotsDuringPass: [SatelliteSnapshot]
    public var lineWidth: CGFloat = 1
    public var illuminatedColor: UIColor
    public var unlitColor: UIColor
    public var arrowSize: CGFloat = 8

    public init(rect: CGRect, snapshotsDuringPass: [SatelliteSnapshot], lineWidth: CGFloat = 1, illuminatedColor: UIColor, unlitColor: UIColor, arrowSize: CGFloat = 8) {
        self.rect = rect
        self.snapshotsDuringPass = snapshotsDuringPass
        self.lineWidth = lineWidth
        self.illuminatedColor = illuminatedColor
        self.unlitColor = unlitColor
        self.arrowSize = arrowSize
    }
}

public struct BackgroundSkyRenderParams {
    public var rect: CGRect
    public var stars: [Star]
    public var constellations: Set<Constellation>
    public var observer: LatLonAlt
    public var julianDate: Double
    public var starColor: UIColor
    public var constellationLineColor: UIColor
    public var constellationLineWidth: CGFloat = 1
    public var drawPlanaryBodies: Bool = false
    public var backgroundFillColor: UIColor = .clear

    public struct Border {
        public var borderColor: UIColor
        public var borderWidth: CGFloat = 1

        public init(borderColor: UIColor, borderWidth: CGFloat = 1) {
            self.borderColor = borderColor
            self.borderWidth = borderWidth
        }
    }

    public var border: Border? = nil
    public var magToRadius: (Double) -> CGFloat

    public init(rect: CGRect, stars: [Star], constellations: Set<Constellation>, observer: LatLonAlt, julianDate: Double, starColor: UIColor, constellationLineColor: UIColor, constellationLineWidth: CGFloat = 1, drawPlanaryBodies: Bool = false, backgroundFillColor: UIColor = .clear, border: BackgroundSkyRenderParams.Border? = nil, magToRadius: @escaping (Double) -> CGFloat) {
        self.rect = rect
        self.stars = stars
        self.constellations = constellations
        self.observer = observer
        self.julianDate = julianDate
        self.starColor = starColor
        self.constellationLineColor = constellationLineColor
        self.constellationLineWidth = constellationLineWidth
        self.drawPlanaryBodies = drawPlanaryBodies
        self.backgroundFillColor = backgroundFillColor
        self.border = border
        self.magToRadius = magToRadius
    }
}
