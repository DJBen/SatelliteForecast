//
//  RealtimeSkySatelliteCell.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/9/22.
//

import SatelliteForecastCore
import SatelliteKit
import SwiftUI
import QSMag

struct RealtimeSkySatelliteCell: View {
    var satelliteName: String
    var snapshot: SatelliteSnapshot

    var body: some View {
        HStack {
            Text(
                satelliteName
            )
            .font(.body)

            Spacer()

            Text(
                snapshot.visualMagnitude.map( RealtimeSkySatelliteCell.formattedMagnitude) ?? ""
            )
            .font(.body)
            .foregroundColor(.secondary)
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
    static var previews: some View {
        let tle = try! TLE(
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

        RealtimeSkySatelliteCell(
            satelliteName: "TIANHE",
            snapshot: try! SatelliteSnapshot(
                tle: tle,
                julianDate: startDate.julianDate,
                observer: observer,
                qsMag: QSMag.with(noradIndex: 25544)!
            )
        )
    }
}

#endif
