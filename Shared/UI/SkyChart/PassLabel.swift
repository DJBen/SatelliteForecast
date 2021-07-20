//
//  PassLabel.swift
//  PassLabel
//
//  Created by Ben Lu on 7/19/21.
//

import SwiftUI
import SwiftUIVisualEffects
import SatelliteKit
import SatelliteForcastCore

extension SkyChart {
    struct PassLabel: View {
        let text: String
        let snapshotPair: SkyChartViewState.SnapshotsAroundPass
        let rect: CGRect
        
        var body: some View {
            let (rot, textRotation) = SkyChart.rotationAndTextRotation(snapshotPair: snapshotPair, rect: rect)
            let textPosition = AziEleDst(azim: snapshotPair.first.position.azim, elev: snapshotPair.first.position.elev, dist: 0)
            return HStack(spacing: 2) {
                Path { path in
                    path.move(to: CGPoint(x: rect.midX, y: rect.midY))
                    path.addLine(to: CGPoint(x: rect.midX + 20, y: rect.midY))
                }
                .stroke(Color.gray)
                .frame(alignment: .leading)

                Text(text)
                    .passInfoLabelModifiers()
                    .rotationEffect(.radians(textRotation))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .offset(x: 20, y: 0)
            }
            .rotationEffect(.radians(rot))
            .position(SkyChart.point(at: textPosition, rect: rect))
        }
    }
}

fileprivate extension View {
    func passInfoLabelModifiers() -> some View {
        return fixedSize()
            .padding(4)
            .foregroundColor(Color("passInfoLabel_foreground"))
            .font(.caption.weight(.semibold).monospaced())
            .background(
                Color.clear.blurEffect()
                    .cornerRadius(8)
            )
    }
}
