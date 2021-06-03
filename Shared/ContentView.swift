//
//  ContentView.swift
//  Shared
//
//  Created by Ben Lu on 5/28/21.
//

import CoreLocation
import SwiftUI
import ASCollectionView
import SatelliteKit

struct ContentView: View {
    let viewModel: SatelliteWidgetViewModel

    var body: some View {
        ASCollectionView(data: viewModel.sortedDateHorizontalCoordinates) { item, _ in
            Color.blue
                .overlay(
                    List {
                        Text("\(item.horizontalCoordinate.azim)")
                        Text("\(item.horizontalCoordinate.elev)")
                        Text("\(item.horizontalCoordinate.dist)")
                    }
                )
        }
        .layout {
            .grid(
                layoutMode: .adaptive(withMinItemSize: 200),
                itemSpacing: 5,
                lineSpacing: 5,
                itemSize: .absolute(200))
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static let viewModel: SatelliteWidgetViewModel = {
        let tle = try! TLE(
            raw: """
            ISS (ZARYA)
            1 25544U 98067A   21150.17525219  .00001216  00000-0  30289-4 0  9997
            2 25544  51.6454  71.8132 0003443  45.7908  95.8066 15.48936547285805
            """
        )
        let sat = Satellite(withTLE: tle)

        let formatter = ISO8601DateFormatter()
        let date = formatter.date(from: "2021-06-02T20:36:08+0800")!

        return SatelliteWidgetViewModel(
            satelliteName: tle.commonName,
            sortedDateHorizontalCoordinates: (0..<30)
                .map { date.addingTimeInterval(Double($0 * 30)) }
                .map { (currentDate) -> DateHorizontalCoordinate in
                    let aziEleDst = sat.topPosition(
                        julianDays: currentDate.julianDate,
                        observer: LatLonAlt(lat: 32.0669, lon: 118.8251, alt: 0)
                    )
                    return DateHorizontalCoordinate(
                        date: currentDate,
                        horizontalCoordinate: aziEleDst,
                        isIlluminated: true
                    )
                }
        )
    }()
    static var previews: some View {
        ContentView(viewModel: viewModel)
    }
}

extension DateHorizontalCoordinate: Identifiable {
    var id: String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: date)
    }
}
