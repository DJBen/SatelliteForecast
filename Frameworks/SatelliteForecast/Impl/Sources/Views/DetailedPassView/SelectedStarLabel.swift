//
//  SelectedStarLabel.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 11/22/22.
//

import SwiftUI
import StarryNight
@preconcurrency import SatelliteKit

struct SelectedStarLabel: View {
    @Environment(\.colorScheme) var colorScheme

    let starManager: any StarManaging
    let star: Star
    @State var starInfo: StarInfo?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(
                    primaryStarDescription ?? ""
                )
                .font(.title2)
                .foregroundColor(Color(UIColor.label))

                if let secondaryStarDescription = secondaryStarDescription {
                    Text(
                        secondaryStarDescription
                    )
                    .font(.subheadline)
                    .foregroundColor(Color(UIColor.secondaryLabel))
                }

                Spacer()

                Text(
                    starInfo?.constellation?.name ?? ""
                )
                .font(.headline)
                .foregroundColor(Color(UIColor.secondaryLabel))
            }

            Text(
                LocalizedStrings.magnitudeText(magnitude: star.magnitude)
            )
            .font(.body)
            .foregroundColor(Color(UIColor.secondaryLabel))

            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(
                    LocalizedStrings.rightAscensionText(raDec: RADec(vector: star.coordinate))
                )
                .font(.caption)
                .foregroundColor(Color(UIColor.secondaryLabel))

                Text(
                    LocalizedStrings.declinationText(raDec: RADec(vector: star.coordinate))
                )
                .font(.caption)
                .foregroundColor(Color(UIColor.secondaryLabel))
            }
        }
        .task {
            starInfo = starManager.starInfo(forId: star.id)
        }
    }

    private var primaryStarDescription: String? {
        starInfo?.displayName
    }

    private var secondaryStarDescription: String? {
        let candidates: [String?] = [
            starInfo?.properName,
            starInfo?.bayerFlamsteedDesignation,
            starInfo?.gl,
            starInfo?.hrIdString,
            starInfo?.hdIdString,
            starInfo?.hipIdString
        ]
        var foundFirst: Bool = false
        for candidate in candidates {
            if candidate != nil {
                if foundFirst {
                    return candidate
                } else {
                    foundFirst = true
                }
            }
        }
        return nil
    }
}

extension SelectedStarLabel {
    enum LocalizedStrings {
        static func magnitudeText(magnitude: Double) -> String {
            return String(
                format: NSLocalizedString(
                    "SelectedStarLabel.magnitudeText.format",
                    tableName: nil,
                    bundle: .module,
                    value: "Magnitude %.1f star",
                    comment: "Description of the star magnitude in SelectedStarLabel."
                ),
                magnitude
            )
        }

        static func rightAscensionText(raDec: RADec) -> String {
            return String(
                format: NSLocalizedString(
                    "SelectedStarLabel.rightAscensionText.format",
                    tableName: nil,
                    bundle: .module,
                    value: "RA: %@",
                    comment: "Description of the right ascension in SelectedStarLabel."
                ),
                raDec.formattedRA
            )
        }

        static func declinationText(raDec: RADec) -> String {
            return String(
                format: NSLocalizedString(
                    "SelectedStarLabel.declinationText.format",
                    tableName: nil,
                    bundle: .module,
                    value: "DEC: %@",
                    comment: "Description of the declination in SelectedStarLabel."
                ),
                raDec.formattedDec
            )
        }
    }
}
