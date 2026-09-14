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

    let starManager: AppStarCatalog
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
                    .foregroundColor(AppTheme.muted)
                }

                Spacer()

                Text(
                    starInfo?.constellation?.localizedName ?? ""
                )
                .font(.headline)
                .foregroundColor(AppTheme.muted)
            }

            Text(
                LocalizedStrings.magnitudeText(magnitude: star.magnitude)
            )
            .font(.body)
            .foregroundColor(AppTheme.muted)

            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(
                    LocalizedStrings.rightAscensionText(raDec: RADec(star.coordinate))
                )
                .font(.caption)
                .foregroundColor(AppTheme.muted)

                Text(
                    LocalizedStrings.declinationText(raDec: RADec(star.coordinate))
                )
                .font(.caption)
                .foregroundColor(AppTheme.muted)
            }
        }
        .task(id: star.id) {
            starInfo = nil
            do {
                let info = try await starManager.starInfo(forId: star.id)
                try Task.checkCancellation()
                starInfo = info
            } catch is CancellationError {
                // A new selection superseded this request.
            } catch {
                starInfo = nil
            }
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
