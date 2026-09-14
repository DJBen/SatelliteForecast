import UIKit

public enum SkyChartAction {
    case requestRasterizedSatellitePath(
        size: CGSize,
        quality: ChartQuality,
        passSnapshots: PassSnapshots, // For drawing the path
        traitCollection: UITraitCollection
    )
}

extension SkyChartAction: Equatable {}
