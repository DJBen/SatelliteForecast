import SwiftUI
import AVFoundation

/// Test-only controls for volatile media; production rendering uses live playback.
enum SnapshotEnvironment {
    static var isEnabled: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["SATELLITE_SNAPSHOT_TESTS"] == "1"
        #else
        false
        #endif
    }

    static func videoFrame(url: URL) -> UIImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        guard let image = try? generator.copyCGImage(at: CMTime(seconds: 2, preferredTimescale: 600), actualTime: nil) else { return nil }
        return UIImage(cgImage: image)
    }
}
