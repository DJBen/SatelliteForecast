//
//  ConstellationLabel.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 5/15/22.
//

import SwiftUI

public struct ConstellationLabel: View {
    let text: String

    public var body: some View {
        Text(
            text
        )
        .font(.system(.caption, design: .serif))
        .foregroundColor(.secondary)
    }
}
