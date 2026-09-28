import SwiftUI
import UIKit

/// Shared dark appearance for the app, chart overlays and WidgetKit extension.
/// Keep physical sky/stellar colors independent of these interface colors.
public enum MoonstonePalette {
    public static let backgroundHex: UInt32 = 0x111214
    public static let surfaceHex: UInt32 = 0x1C1E22
    public static let textHex: UInt32 = 0xECEEF2
    public static let mutedHex: UInt32 = 0xA3A8B2
    public static let accentHex: UInt32 = 0xA9B9CE
    public static let borderHex: UInt32 = 0x33363D
    public static let warningHex: UInt32 = 0xF0A184
    /// Coral that marks a pass happening now, in the app and the widget.
    public static let passingHex: UInt32 = 0xFF7D6E

    public static func uiColor(_ hex: UInt32) -> UIColor {
        UIColor(red: CGFloat((hex >> 16) & 255) / 255,
                green: CGFloat((hex >> 8) & 255) / 255,
                blue: CGFloat(hex & 255) / 255, alpha: 1)
    }
    public static let background = Color(uiColor: uiColor(backgroundHex))
    public static let surface = Color(uiColor: uiColor(surfaceHex))
    public static let text = Color(uiColor: uiColor(textHex))
    public static let muted = Color(uiColor: uiColor(mutedHex))
    public static let accent = Color(uiColor: uiColor(accentHex))
    public static let passing = Color(uiColor: uiColor(passingHex))

    public static func vector(_ hex: UInt32, alpha: Float) -> SIMD4<Float> {
        SIMD4(Float((hex >> 16) & 255) / 255, Float((hex >> 8) & 255) / 255,
              Float(hex & 255) / 255, alpha)
    }
}

/// Static, low-contrast matte finish. The tiny deterministic tile is generated once,
/// never per animation frame. Accessibility contrast/transparency settings use a solid fill.
public struct MoonstoneBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    private let base: Color
    private let glowOpacity: Double

    public init(base: Color = MoonstonePalette.background, glowOpacity: Double = 0.10) {
        self.base = base
        self.glowOpacity = glowOpacity
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack {
                base
                if colorScheme == .dark && contrast != .increased && !reduceTransparency {
                    RadialGradient(colors: [MoonstonePalette.accent.opacity(glowOpacity), .clear],
                        center: UnitPoint(x: 0.60, y: 1.05), startRadius: 0,
                        endRadius: max(proxy.size.width, proxy.size.height) * 0.8)
                    Image(uiImage: Self.grain).resizable(resizingMode: .tile).opacity(0.015)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private static let grain: UIImage = {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 96, height: 96), format: format).image { renderer in
            var seed: UInt64 = 0x534B59
            for y in 0..<96 {
                for x in 0..<96 {
                    seed = seed &* 6364136223846793005 &+ 1
                    let value = CGFloat((seed >> 33) & 255) / 255
                    renderer.cgContext.setFillColor(UIColor(white: value, alpha: 1).cgColor)
                    renderer.cgContext.fill(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }
        }
    }()
}
