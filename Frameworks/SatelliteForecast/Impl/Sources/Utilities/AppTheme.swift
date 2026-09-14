import SwiftUI
import UIKit

/// Shared semantic colors for navigation, cards and chart annotations.
public enum AppTheme {
    public static var background: Color { Color(uiColor: backgroundColor) }
    public static var surface: Color { Color(uiColor: surfaceColor) }
    public static var accent: Color { Color(uiColor: accentColor) }
    public static var muted: Color { Color(uiColor: mutedColor) }
    public static var warning: Color { Color(uiColor: warningColor) }
    public static var border: Color { Color(uiColor: borderColor) }

    public static let backgroundColor = adaptive(light: 0xF1F5F7, dark: 0x0A1321)
    public static let surfaceColor = adaptive(light: 0xFFFFFF, dark: 0x142233)
    public static let accentColor = adaptive(light: 0x006C78, dark: 0x70DAD2)
    public static let mutedColor = adaptive(light: 0x536575, dark: 0xA7B8CB)
    public static let warningColor = adaptive(light: 0x8A5000, dark: 0xF4C47A)
    public static let borderColor = adaptive(light: 0xD6E0E7, dark: 0x2B4054)
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
            .background(AppTheme.background.ignoresSafeArea())
            .tint(AppTheme.accent)
    }
}
