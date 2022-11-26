//
//  PassLabel.swift
//  PassLabel
//
//  Created by Ben Lu on 7/19/21.
//

import SwiftUI
import SwiftUIVisualEffects
import SatelliteKit
import SatelliteForecast

struct SkyChartPassLabel<BackgroundModifier: ViewModifier, Content: View>: View {
    let snapshotPair: SnapshotsAroundPass
    let rect: CGRect
    let modifierFactory: (Angle) -> BackgroundModifier
    let content: () -> Content

    public init(
        snapshotPair: SnapshotsAroundPass,
        rect: CGRect,
        modifierFactory: @escaping (Angle) -> BackgroundModifier,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.snapshotPair = snapshotPair
        self.rect = rect
        self.modifierFactory = modifierFactory
        self.content = content
    }

    var body: some View {
        let (rot, textRotation) = SkyChartUtils.rotationAndTextRotation(snapshotPair: snapshotPair, rect: rect)
        let textPosition = AziEleDst(azim: snapshotPair.first.position.azim, elev: snapshotPair.first.position.elev, dist: 0)
        return HStack(spacing: 2) {
            Path { path in
                path.move(to: CGPoint(x: rect.midX, y: rect.midY))
                path.addLine(to: CGPoint(x: rect.midX + 20, y: rect.midY))
            }
            .stroke(Color.gray)
            .frame(alignment: .leading)

            content(
            )
            .modifier(modifierFactory(.radians(textRotation)))
            .rotationEffect(.radians(textRotation))
            .frame(maxWidth: .infinity, alignment: .leading)
            .offset(x: 20, y: 0)
        }
        .rotationEffect(.radians(rot))
        .position(SkyChartUtils.point(at: textPosition, rect: rect))
    }
}


struct PassLabelModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    var rotationAngle: Angle = .zero

    init(rotationAngle: Angle) {
        self.rotationAngle = rotationAngle
    }

    func body(content: Content) -> some View {
        content.fixedSize()
            .padding(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
            .font(.caption.weight(.semibold).monospaced())
            .background(
                RoundedRectangle(
                    cornerRadius: 8,
                    style: .continuous
                )
                .stroke(
                    Color(
                        uiColor: .label
                    ),
                    lineWidth: 2
                )
                .vibrancyEffect()
                .background(
                    Color.clear.blurEffect()
                )
                .cornerRadius(8)
                .blurEffectStyle(colorScheme == .light ? .systemChromeMaterialLight : .systemChromeMaterialDark)
                .vibrancyEffectStyle(.fill)
                .rotationEffect(rotationAngle)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct HighlightedPassLabelModifier: ViewModifier {
    var rotationAngle: Angle = .zero
    var shouldHighlight: Bool = true

    static func curry(shouldHighlight: Bool) -> (Angle) -> HighlightedPassLabelModifier {
        {
            self.init(rotationAngle: $0, shouldHighlight: shouldHighlight)
        }
    }

    func body(content: Content) -> some View {
        let gradient = shouldHighlight ? Gradient(colors: [Color(UIColor.systemPink), Color(UIColor.systemOrange)]) : Gradient(colors: [Color(UIColor.systemGray), Color(UIColor.systemGray2)])
        content.fixedSize()
            .padding(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
            .foregroundColor(Color("passInfoLabel_foreground", bundle: .satelliteForecastImplResourcesBundle))
            .font(.caption.weight(.semibold).monospaced())
            .background(LinearGradient(gradient: gradient, startPoint: .leading, endPoint: .trailing).rotationEffect(rotationAngle))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
