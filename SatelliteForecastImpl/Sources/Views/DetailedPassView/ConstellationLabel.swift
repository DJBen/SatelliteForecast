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
        .font(.caption)
        .foregroundColor(.secondary)
    }
}

#if DEBUG

struct ConstellationLabel_Previews: PreviewProvider {
    static var previews: some View {
        ConstellationLabel(text: "Hello")
    }
}

#endif
