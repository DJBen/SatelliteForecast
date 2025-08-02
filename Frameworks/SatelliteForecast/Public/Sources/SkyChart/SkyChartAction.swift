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

public enum SkyChartOutput {
    /// A satellite path is rasterized, or the rasterized image is read from the cache.
    case rasterizedSatellitePath(UIImage, quality: ChartQuality, pass: Pass)
}
