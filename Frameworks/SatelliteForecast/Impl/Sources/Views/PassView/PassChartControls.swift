import SwiftUI

/// Keep every destination readable, including long translations and accessibility sizes.
struct PassChartControls: View {
    @Binding var isCompassEnabled: Bool
    var openChart: () -> Void
    var openPlanetarium: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 10) { buttons(stacked: false, intrinsic: false) }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { buttons(stacked: false, intrinsic: true) }
                    HStack(spacing: 8) { buttons(stacked: false, intrinsic: true, compactCompass: true) }
                    HStack(spacing: 8) { buttons(stacked: true, intrinsic: true, compactCompass: true) }
                    HStack(alignment: .top, spacing: 8) { buttons(stacked: true, intrinsic: false, compactCompass: true) }
                }
            }
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.roundedRectangle(radius: 16))
    }

    @ViewBuilder
    private func buttons(stacked: Bool, intrinsic: Bool, compactCompass: Bool = false) -> some View {
        if isCompassEnabled {
            compass(stacked: stacked, intrinsic: intrinsic, iconOnly: compactCompass).buttonStyle(.glassProminent)
        } else {
            compass(stacked: stacked, intrinsic: intrinsic, iconOnly: compactCompass)
        }
        Button(action: openChart) {
            label("Chart", icon: "arrow.up.left.and.arrow.down.right", stacked: stacked, intrinsic: intrinsic)
        }
        .accessibilityIdentifier("pass.chart")
        Button(action: openPlanetarium) {
            label(compactCompass ? "3D" : "Planetarium", icon: "cube.transparent", stacked: stacked, intrinsic: intrinsic)
        }
        .accessibilityLabel(Text("Planetarium", bundle: .module))
        .accessibilityIdentifier("pass.planetarium")
    }

    private func compass(stacked: Bool, intrinsic: Bool, iconOnly: Bool) -> some View {
        Button { isCompassEnabled.toggle() } label: {
            label("Compass", icon: isCompassEnabled ? "safari.fill" : "safari",
                  stacked: stacked, intrinsic: intrinsic, iconOnly: iconOnly)
                .foregroundStyle(isCompassEnabled
                    ? (colorScheme == .dark ? AppTheme.background : Color.white)
                    : AppTheme.accent)
        }
        .accessibilityLabel(Text("Compass", bundle: .module))
        .accessibilityValue(isCompassEnabled ? "On" : "Off")
        .accessibilityAddTraits(isCompassEnabled ? .isSelected : [])
    }

    private func label(_ title: LocalizedStringKey, icon: String, stacked: Bool, intrinsic: Bool, iconOnly: Bool = false) -> some View {
        let layout = stacked ? AnyLayout(VStackLayout(spacing: 4)) : AnyLayout(HStackLayout(spacing: 6))
        return layout {
            Image(systemName: icon)
                .font(.body)
                .accessibilityHidden(true)
            if !iconOnly {
                Text(title, bundle: .module)
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.center)
                .lineLimit(stacked && !intrinsic ? 3 : 100, reservesSpace: stacked && !intrinsic)
                .fixedSize(horizontal: intrinsic, vertical: true)
            }
        }
        .frame(minWidth: iconOnly ? 24 : nil, maxWidth: iconOnly ? nil : .infinity)
        .padding(.vertical, 4)
        .frame(minHeight: 36)
        .contentShape(Rectangle())
    }
}
