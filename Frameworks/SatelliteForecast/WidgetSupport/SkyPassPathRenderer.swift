import UIKit

/// The app and widget share the same north-up projection, illumination segments and arrows.
public enum SkyPassPathRenderer {
    public static func draw(in context: CGContext, rect: CGRect, track: [WidgetSkyPoint],
                            lineWidth: CGFloat, illuminatedColor: UIColor, unlitColor: UIColor,
                            arrowSize: CGFloat = 8) {
        guard track.count > 1 else { return }
        func point(_ sample: WidgetSkyPoint) -> CGPoint {
            let radius = (90 - sample.elevation) / 90 * min(rect.width, rect.height) / 2
            let angle = sample.azimuth * .pi / 180
            return CGPoint(x: rect.midX - sin(angle) * radius, y: rect.midY - cos(angle) * radius)
        }
        context.saveGState()
        defer { context.restoreGState() }
        var start = 0
        while start < track.count - 1 {
            var end = start + 1
            while end < track.count - 1 && track[end].illuminated == track[start].illuminated {
                end += 1
            }
            let color = track[start].illuminated ? illuminatedColor : unlitColor
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(lineWidth)
            context.move(to: point(track[start]))
            for index in (start + 1)...end { context.addLine(to: point(track[index])) }
            context.strokePath()
            if end - start + 1 > 3 {
                let middle = start + (end - start + 1) / 2
                let p1 = point(track[middle - 1]), p2 = point(track[middle])
                context.saveGState()
                context.translateBy(x: p1.x, y: p1.y)
                context.rotate(by: atan2(p2.y - p1.y, p2.x - p1.x))
                context.setFillColor(color.cgColor)
                if let mask = UIImage(systemName: "arrowtriangle.right.fill")?.cgImage {
                    let bounds = CGRect(x: -arrowSize / 2, y: -arrowSize / 2, width: arrowSize, height: arrowSize)
                    context.clip(to: bounds, mask: mask)
                    context.fill(bounds)
                }
                context.restoreGState()
            }
            start = end
        }
    }
}
