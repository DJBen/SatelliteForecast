import SwiftUI
import SatelliteForecast

/// Detail follows the usable chart diameter, including narrow iPad windows.
enum SkyChartDetail {
    static func maximumMagnitude(diameter: CGFloat) -> Double {
        diameter < 240 ? 3 : (diameter < 480 ? 4.5 : 5.5)
    }

    static func configs(diameter: CGFloat) -> BackgroundSkyConfigs {
        configs(magnitude: maximumMagnitude(diameter: diameter), names: diameter >= 480)
    }

    static func configs(magnitude: Double, names: Bool) -> BackgroundSkyConfigs {
        BackgroundSkyConfigs(stars: .limitedMagnitude(magnitude),
            starMagToDisplayRadiusMappingFunction: magnitude > 6 ? .init(id: "chart-faint-detail") { mag in
                let radius = BackgroundSkyConfigs.StarMagToDisplayRadiusMappingFunction.pointSourceRadius(magnitude: mag)
                return mag > 6 ? max(0.3, radius * exp(-0.2 * (mag - 6))) : radius
            } : .default,
            showConstellationNames: names)
    }
}

/// Deterministic label placement shared by star and constellation annotations.
/// Boxes include a readable gap; every corner must stay inside the sky's horizon.
struct SkyChartLabelLayout {
    let bounds: CGRect
    var occupied: [CGRect] = []

    mutating func place(size: CGSize, near anchor: CGPoint, canMove: Bool = true) -> CGRect? {
        guard size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0,
              anchor.x.isFinite, anchor.y.isFinite else { return nil }
        let step = size.height + 12
        let offsets = canMove ? [CGPoint.zero, CGPoint(x: 0, y: -step), CGPoint(x: 0, y: step),
            CGPoint(x: 0, y: -2 * step), CGPoint(x: 0, y: 2 * step)] : [.zero]
        let radius = min(bounds.width, bounds.height) / 2 - 8
        for offset in offsets {
            let box = CGRect(x: anchor.x + offset.x - size.width / 2,
                y: anchor.y + offset.y - size.height / 2, width: size.width, height: size.height)
                .insetBy(dx: -5, dy: -4)
            let corners = [CGPoint(x: box.minX, y: box.minY), CGPoint(x: box.maxX, y: box.minY),
                CGPoint(x: box.minX, y: box.maxY), CGPoint(x: box.maxX, y: box.maxY)]
            guard corners.allSatisfy({ hypot($0.x - bounds.midX, $0.y - bounds.midY) < radius }),
                  !occupied.contains(where: { $0.intersects(box) }) else { continue }
            occupied.append(box)
            return box
        }
        return nil
    }
}
