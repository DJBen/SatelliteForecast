//
//  RealtimeSkySatelliteCell.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 3/9/22.
//

import SatelliteForecast
@preconcurrency import SatelliteKit
import SwiftUI
import QSMag

struct RealtimeSkySatelliteCell: View {
    @Binding var isFocused: Bool
    var satelliteInfo: SatelliteInfo
    var snapshot: SatelliteSnapshot

    private var magnitudeText: String {
        if snapshot.isIlluminated {
            return snapshot.visualMagnitude.map( RealtimeSkySatelliteCell.formattedMagnitude) ?? ""
        } else {
            return NSLocalizedString(
                "RealtimeSkySatelliteCell.magnitudeText.notIlluminated",
                tableName: nil,
                bundle: .module,
                value: "Not illuminated",
                comment: """
                The text indicating the satellite is not illuminated.
                """
            )
        }
    }

    private func distanceText(_ distance: Double) -> String {
        let format = NSLocalizedString(
            "RealtimeSkySatelliteCell.distanceText",
            tableName: nil,
            bundle: .module,
            value: "Distance %@ km",
            comment: """
                The format text showing the distance betweent the satellite to the observer
                """
        )
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 1
        return String(format: format, formatter.string(from: distance as NSNumber)!)
    }

    var body: some View {
        HStack {
            Image(
                systemName: isFocused ? "circle.inset.filled" : "circle"
            )
            .foregroundColor(isFocused ? .orange : Color(UIColor.tertiaryLabel))

            VStack(alignment: .leading) {
                HStack {
                    Text(
                        satelliteInfo.ucsSat?.officialName ?? satelliteInfo.elements.commonName
                    )
                    .font(.body)

                    Spacer()

                    Text(
                        magnitudeText
                    )
                    .font(.body)
                    .foregroundColor(.secondary)
                }

                HStack {
                    Text(
                        distanceText(snapshot.distance)
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
        }
    }
}

extension RealtimeSkySatelliteCell {
    static func formattedMagnitude(_ magnitude: Double) -> String {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 1
        return formatter.string(from: magnitude as NSNumber)!
    }
}
