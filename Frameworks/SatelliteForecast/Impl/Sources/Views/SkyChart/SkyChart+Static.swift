//
//  SkyChart+Static.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 6/17/21.
//

import BTree
import UIKit
import SatelliteWidgetSupport
import SatelliteForecast
@preconcurrency import SatelliteKit
import StarryNight
import SolarSystem
import simd

public enum SkyChartUtils {
    public static var labelDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("H:mm:ss")
        return formatter
    }

    public static var labelAngleFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 0
        return formatter
    }

    public static func radius(fromRect rect: CGRect) -> CGFloat {
        return min(rect.width, rect.height) / 2
    }

    /// Convert the polar coordinates to cartesian coordinate bounded in a rect.
    /// - Parameters:
    ///   - coordinate: The polar coordinate
    ///   - rect: The bounding rectangle.
    /// - Returns: The cartesian coordinate bounded by a rectangle.
    public static func point(at coordinate: AziEle, rect: CGRect) -> CGPoint {
        let dist = (90 - coordinate.elev) / 90.0 * Double(radius(fromRect: rect))
        let xOffset = sin(coordinate.azim * deg2rad) * dist
        let yOffset = cos(coordinate.azim * deg2rad) * dist
        return CGPoint(x: rect.midX - CGFloat(xOffset), y: rect.midY - CGFloat(yOffset))
    }

    public static func aziEle(at point: CGPoint, in rect: CGRect) -> AziEle {
        let x = rect.midX - point.x
        let y = rect.midY - point.y
        let azi = limit360(atan2(x, y) * rad2deg)
        let radius = min(rect.width, rect.height) / 2
        let ele = (radius - sqrt(x * x + y * y)) / radius * 90
        return AziEle(Double(azi), Double(ele))
    }

    public static func azimuthMarkPoints(azimuth: Double, length: CGFloat, rect: CGRect) -> (CGPoint, CGPoint) {
        func point(_ azim: Double, dist: Double) -> CGPoint {
            let xOffset = sin(azim * deg2rad) * dist
            let yOffset = cos(azim * deg2rad) * dist
            return CGPoint(x: rect.midX - CGFloat(xOffset), y: rect.midY - CGFloat(yOffset))
        }
        return (
            point(azimuth, dist: Double(radius(fromRect: rect))),
            point(azimuth, dist: Double(radius(fromRect: rect) + length))
        )
    }

    /// The rotation angle in radians, and the rotation angle for the text to be the most legible.
    /// - Parameters:
    ///   - snapshotPair: A pair of satellite snapshots.
    ///   - rect: The rectangle of the view.
    /// - Returns: The rotation angle in radians, and the rotation angle for the text to be the most legible.
    public static func rotationAndTextRotation(snapshotPair: SnapshotsAroundPass, rect: CGRect) -> (Double, Double) {
        let position = Self.point(at: AziEle(snapshotPair.first.position), rect: rect)
        let afterPosition = Self.point(at: AziEle(snapshotPair.second.position), rect: rect)
        let satellitePositionVector = SIMD3<Double>(Double(afterPosition.x - position.x), Double(afterPosition.y - position.y), 0)
        // A vector from origin to the position
        let originVector = SIMD3<Double>(Double(afterPosition.x - rect.midX), Double(afterPosition.y - rect.midY), 0)
        let normal = simd_cross(satellitePositionVector, originVector)
        let rot = atan2(Double(afterPosition.y - position.y), Double(afterPosition.x - position.x))
        let factor: Double = normal.z > 0 ? -1 : 1
        let adjustedRot = factor > 0 ? rot + .pi / 2 : rot - .pi / 2
        let textRot = fmod2pi_0(adjustedRot) > .pi / 2 || fmod2pi_0(adjustedRot) < -.pi / 2 ? .pi : 0
        return (adjustedRot, textRot)
    }
    
    public static func addRasterizedSatellitePassPath(
        to ctx: UIGraphicsImageRendererContext,
        params: SatellitePassPathRenderParams
    ) {
        SkyPassPathRenderer.draw(in: ctx.cgContext, rect: params.rect,
            track: params.snapshotsDuringPass.map {
                WidgetSkyPoint(azimuth: $0.position.azim, elevation: $0.position.elev, illuminated: $0.isIlluminated)
            }, lineWidth: params.lineWidth, illuminatedColor: params.illuminatedColor,
            unlitColor: params.unlitColor, arrowSize: params.arrowSize)
    }

    public static func rasterizedSatellitePassPath(
        params: SatellitePassPathRenderParams
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: params.rect.size)

        return renderer.image { ctx in
            addRasterizedSatellitePassPath(to: ctx, params: params)
        }
    }

    public static func addRasterizedBackgroundSkyPath(
        to ctx: UIGraphicsImageRendererContext,
        params: BackgroundSkyRenderParams,
        starManager: AppStarCatalog?
    ) {
        if let border = params.border {
            ctx.cgContext.saveGState()
            ctx.cgContext.setStrokeColor(border.borderColor.cgColor)
            ctx.cgContext.addEllipse(in: params.rect)
            ctx.cgContext.setLineWidth(border.borderWidth)
            ctx.cgContext.drawPath(using: .stroke)
            ctx.cgContext.restoreGState()
        }
        
        // -- Background fill
        
        ctx.cgContext.saveGState()
        ctx.cgContext.setFillColor(params.backgroundFillColor.cgColor)
        ctx.cgContext.addEllipse(in: params.rect)
        ctx.cgContext.fillPath()
        ctx.cgContext.restoreGState()
        
        // Project diffuse Galactic light beneath the catalog stars and lines.
        ctx.cgContext.saveGState()
        ctx.cgContext.addEllipse(in: params.rect)
        ctx.cgContext.clip()
        MilkyWayBackground.image(size: params.rect.size, observer: params.observer,
            julianDate: params.julianDate,
            dark: UITraitCollection.current.userInterfaceStyle == .dark)?.draw(in: params.rect)
        ctx.cgContext.restoreGState()

        // -- Constellations --
        
        ctx.cgContext.saveGState()
        ctx.cgContext.setStrokeColor(params.constellationLineColor.cgColor)
        ctx.cgContext.setLineWidth(params.constellationLineWidth)

        for constellation in params.constellations {
            let alt = azel(
                time: Date(julianDate: params.julianDate),
                site: LatLon(params.observer),
                cele: RADec(constellation.center)
            ).elev
            if alt < 0 {
                continue
            }
            for line in (starManager?.constellationLines(for: constellation) ?? []) {
                guard let star1 = starManager?.star(withId: line.star1Id),
                      let star2 = starManager?.star(withId: line.star2Id) else { continue }
                let aziElev1 = azel(time: Date(julianDate: params.julianDate), site: LatLon(params.observer), cele: RADec(star1.coordinate))
                let aziElev2 = azel(time: Date(julianDate: params.julianDate), site: LatLon(params.observer), cele: RADec(star2.coordinate))
                if aziElev1.elev < 0 || aziElev2.elev < 0 {
                    continue
                }
                let point1 = Self.point(at: AziEle(aziElev1.azim, aziElev1.elev), rect: params.rect)
                let point2 = Self.point(at: AziEle(aziElev2.azim, aziElev2.elev), rect: params.rect)

                ctx.cgContext.move(to: point1)
                ctx.cgContext.addLine(to: point2)
            }
            ctx.cgContext.drawPath(using: .stroke)
        }
        ctx.cgContext.restoreGState()
        
        // -- Stars --
        
        ctx.cgContext.saveGState()

        for star in params.stars {
            let aziElev = azel(
                time: Date(julianDate: params.julianDate),
                site: LatLon(params.observer),
                cele: RADec(star.coordinate)
            )
            if aziElev.elev < 0 {
                continue
            }
            let point = Self.point(at: AziEle(aziElev.azim, aziElev.elev), rect: params.rect)

            let radius = params.magToRadius(star.magnitude)
            
            // Set color based on spectral class for realistic star colors
            let starColor = SkyChartTheme.starColor(
                spectralClass: star.spectralClass,
                traitCollection: UITraitCollection.current
            )
            ctx.cgContext.setFillColor(starColor.cgColor)
            
            // Draw individual star
            SkyChartTheme.drawPointSource(in: ctx.cgContext, at: point, radius: radius, color: starColor, magnitude: star.magnitude)
        }
        ctx.cgContext.restoreGState()
        
        guard params.drawPlanaryBodies else {
            return
        }
        
        // -- Plantary bodies

        let sunAziElev = azel(
            time: Date(julianDate: params.julianDate),
            site: LatLon(params.observer),
            cele: RADec(
                SolarSystemBody.sun.eci(
                    julianDay: params.julianDate
                )
            )
        )

        let sunPoint = Self.point(at: AziEle(sunAziElev.azim, sunAziElev.elev), rect: params.rect)
        
        ctx.cgContext.saveGState()
        ctx.cgContext.addEllipse(in: params.rect)
        ctx.cgContext.clip()
        
        ctx.cgContext.setFillColor(UIColor.systemYellow.cgColor)
        ctx.cgContext.setShadow(offset: .zero, blur: 16, color: UIColor.systemYellow.cgColor)
        ctx.cgContext.addEllipse(in: CGRect(x: sunPoint.x - 7, y: sunPoint.y - 7, width: 14, height: 14))
        ctx.cgContext.drawPath(using: .fill)

        let moon = MoonAppearance.Geometry(julianDate: params.julianDate, observer: params.observer)
        if moon.coordinate.elev >= 0 {
            let moonPoint = Self.point(at: moon.coordinate, rect: params.rect)
            ctx.cgContext.setShadow(offset: .zero, blur: 0, color: nil)
            MoonAppearance.photograph(geometry: moon, dimension: 48)?.draw(in:
                CGRect(x: moonPoint.x - 15, y: moonPoint.y - 15, width: 30, height: 30))
        }

        ctx.cgContext.restoreGState()
    }
        
    /// Compact charts use the same naked-eye planets, twilight rules and photometry
    /// as PlanetaryBodyView, without text or astronomical-symbol labels.
    static func widgetPlanets(observer: LatLonAlt, julianDate: Double) -> [(body: SolarSystemBody, coordinate: AziEle, magnitude: Double)] {
        let sunElevation = SkyChartAtmosphere.sun(observer: observer, julianDate: julianDate).elev
        return [SolarSystemBody.mercury, .venus, .mars, .jupiter, .saturn].compactMap { body in
            let coordinate = azel(time: Date(julianDate: julianDate), site: LatLon(observer),
                cele: RADec(body.eci(julianDay: julianDate)))
            guard coordinate.elev >= 0, body.visible(sunElevation: sunElevation),
                  let magnitude = body.apparentMagnitude(julianDay: julianDate), magnitude.isFinite else { return nil }
            return (body, coordinate, magnitude)
        }
    }

    static func addUnlabeledPlanetsAndMoon(to context: UIGraphicsImageRendererContext,
                                         rect: CGRect, observer: LatLonAlt, julianDate: Double) {
        let cg = context.cgContext
        cg.saveGState()
        defer { cg.restoreGState() }
        cg.addEllipse(in: rect)
        cg.clip()
        for planet in widgetPlanets(observer: observer, julianDate: julianDate) {
            SkyChartTheme.drawPointSource(in: cg, at: point(at: planet.coordinate, rect: rect),
                radius: max(1, min(3.5, 1.65 - 0.3 * planet.magnitude)),
                color: SkyChartTheme.starColor(traitCollection: UITraitCollection.current), magnitude: planet.magnitude)
        }
        let moon = MoonAppearance.Geometry(julianDate: julianDate, observer: observer)
        if moon.coordinate.elev >= 0 {
            let center = point(at: moon.coordinate, rect: rect)
            MoonAppearance.photograph(geometry: moon, dimension: 48)?.draw(in:
                CGRect(x: center.x - 12, y: center.y - 12, width: 24, height: 24))
        }
    }

    public static func rasterizedBackgroundSkyPath(
        params: BackgroundSkyRenderParams,
        starManager: AppStarCatalog?
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: params.rect.size)

        return renderer.image { ctx in
            addRasterizedBackgroundSkyPath(
                to: ctx,
                params: params,
                starManager: starManager
            )
        }
    }
}
