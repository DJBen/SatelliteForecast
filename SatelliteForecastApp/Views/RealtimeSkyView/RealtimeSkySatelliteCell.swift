//
//  RealtimeSkySatelliteCell.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/9/22.
//

import SatelliteForecast
import SatelliteKit
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
                bundle: .main,
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
            bundle: .main,
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

#if DEBUG

struct RealtimeSkySatelliteCell_Previews: PreviewProvider {
    struct Container {
        @State var isFocused = false
    }

    static let container = Container()

    static var previews: some View {
        let elements = try! Elements(
            raw: """
            ISS (ZARYA)
            1 25544U 98067A   21155.08058252  .00001489  00000-0  35252-4 0  9997
            2 25544  51.6446  47.5538 0003512  61.1482  91.5411 15.48950578286563
            """
        )
        // 2000 Broadway, Redwood City, CA 94063
        let observer = LatLonAlt(lat: 37.486743000691185, lon: -122.22655970246515, alt: 0)
        // Date range
        let startDate = Date(timeIntervalSinceReferenceDate: 20 * 365 * 86400)
        let satelliteInfo = SatelliteInfo(elements: elements)
        RealtimeSkySatelliteCell(
            isFocused: container.$isFocused,
            satelliteInfo: satelliteInfo,
            snapshot: try! SatelliteSnapshot(
                satelliteInfo: satelliteInfo,
                julianDate: startDate.julianDate,
                observer: observer
            )
        )
    }
}

#endif
