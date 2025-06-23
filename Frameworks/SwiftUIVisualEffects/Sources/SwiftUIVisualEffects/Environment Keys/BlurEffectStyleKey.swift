/**
* SwiftUIVisualEffects
*/

import SwiftUI

@MainActor
struct BlurEffectStyleKey: @preconcurrency EnvironmentKey {
    static var defaultValue: UIBlurEffect.Style = .systemMaterial // (Per the human-interface guidelines.)
}
