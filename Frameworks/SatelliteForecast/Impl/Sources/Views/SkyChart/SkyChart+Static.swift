//
//  SkyChart+Static.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 6/17/21.
//

import BTree
import UIKit
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
        let snapshotsByIllumination = params.snapshotsDuringPass.split(inclusivity: .includesSecondElementsInPreviousGroup) { (e1, e2) -> Bool in
            return e1.isIlluminated != e2.isIlluminated
        }
        ctx.cgContext.saveGState()
        for index in snapshotsByIllumination.indices {
            let isIlluminated = snapshotsByIllumination[index].first!.isIlluminated
            let color = isIlluminated ? params.illuminatedColor : params.unlitColor
            let snapshotsGroup = snapshotsByIllumination[index]

            ctx.cgContext.setStrokeColor(color.cgColor)
            ctx.cgContext.setLineWidth(params.lineWidth)
            for i in snapshotsGroup.indices where i < snapshotsGroup.index(before: snapshotsGroup.endIndex) {
                if i == snapshotsGroup.startIndex {
                    let point = point(at: AziEle(snapshotsGroup[i].position), rect: params.rect)
                    ctx.cgContext.move(to: point)
                }
                let nextPoint = point(at: AziEle(snapshotsGroup[snapshotsGroup.index(after: i)].position), rect: params.rect)
                ctx.cgContext.addLine(to: nextPoint)
            }
            ctx.cgContext.drawPath(using: .stroke)
            
            if snapshotsGroup.count > 3 {
                ctx.cgContext.saveGState()

                let e1 = snapshotsGroup[snapshotsGroup.count / 2 - 1].position
                let e2 = snapshotsGroup[snapshotsGroup.count / 2].position
                let p1 = point(at: AziEle(e1), rect: params.rect)
                let p2 = point(at: AziEle(e2), rect: params.rect)
                let rot = atan2pi(Double(p2.y - p1.y), Double(p2.x - p1.x))
                ctx.cgContext.translateBy(x: p1.x, y: p1.y)
                ctx.cgContext.rotate(by: CGFloat(rot))
                ctx.cgContext.setFillColor(color.cgColor)
                let image = UIImage(systemName: "arrowtriangle.right.fill")!
                let imageRect = CGRect(origin: CGPoint(x: -params.arrowSize / 2, y: -params.arrowSize / 2), size: CGSize(width: params.arrowSize, height: params.arrowSize))
                ctx.cgContext.clip(to: imageRect, mask: image.cgImage!)
                ctx.cgContext.fill(imageRect)
                ctx.cgContext.restoreGState()
            }
        }
        ctx.cgContext.restoreGState()
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
        starManager: AppStarCatalog
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
            for line in starManager.constellationLines(for: constellation) {
                guard let star1 = starManager.star(withId: line.star1Id),
                      let star2 = starManager.star(withId: line.star2Id) else { continue }
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
            SkyChartTheme.drawPointSource(in: ctx.cgContext, at: point, radius: radius, color: starColor)
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
        
    public static func rasterizedBackgroundSkyPath(
        params: BackgroundSkyRenderParams,
        starManager: AppStarCatalog
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
