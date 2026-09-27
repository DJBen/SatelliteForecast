import SwiftUI
import UIKit
import SatelliteWidgetSupport

/// Shared semantic colors for navigation, cards and chart annotations.
public enum AppTheme {
    public static var background: Color { Color(uiColor: backgroundColor) }
    public static var surface: Color { Color(uiColor: surfaceColor) }
    public static var accent: Color { Color(uiColor: accentColor) }
    public static var muted: Color { Color(uiColor: mutedColor) }
    public static var warning: Color { Color(uiColor: warningColor) }
    public static var border: Color { Color(uiColor: borderColor) }
    public static var text: Color { Color(uiColor: textColor) }
    public static var pageBackground: some View { MoonstoneBackground(base: background, glowOpacity: 0) }
    public static var featuredBackground: some View { MoonstoneBackground(base: surface, glowOpacity: 0.10) }

    public static let backgroundColor = adaptive(light: 0xF1F5F7, dark: MoonstonePalette.backgroundHex)
    public static let surfaceColor = adaptive(light: 0xFFFFFF, dark: MoonstonePalette.surfaceHex)
    public static let accentColor = adaptive(light: 0x006C78, dark: MoonstonePalette.accentHex)
    public static let mutedColor = adaptive(light: 0x536575, dark: MoonstonePalette.mutedHex)
    public static let warningColor = adaptive(light: 0x8A5000, dark: MoonstonePalette.warningHex)
    public static let borderColor = adaptive(light: 0xD6E0E7, dark: MoonstonePalette.borderHex)
    public static let textColor = adaptive(light: 0x18212B, dark: MoonstonePalette.textHex)
    public static let cardRadius: CGFloat = 20

    private static func adaptive(light: UInt32, dark: UInt32) -> UIColor {
        UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 255) / 255,
                           green: CGFloat((hex >> 8) & 255) / 255,
                           blue: CGFloat(hex & 255) / 255, alpha: 1)
        }
    }
}

struct AppSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scrollContentBackground(.hidden)
            .background(AppTheme.pageBackground.ignoresSafeArea())
            .foregroundStyle(AppTheme.text)
            .tint(AppTheme.accent)
    }
}
