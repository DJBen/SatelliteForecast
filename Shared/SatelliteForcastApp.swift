//
//  SatelliteForcastApp.swift
//  Shared
//
//  Created by Ben Lu on 5/28/21.
//

import SwiftUI
import SatelliteKit
import SatelliteForcastCore

@main
struct SatelliteForcastApp: App {
    var body: some Scene {
        WindowGroup {
            let calendar = Calendar(identifier: .gregorian)
            let tle = try! TLE(
                raw: """
                ISS (ZARYA)
                1 25544U 98067A   21152.11066515  .00000451  00000-0  16375-4 0  9992
                2 25544  51.6453  62.2423 0003364  52.3737  88.5313 15.48937685286109
                """
            )
            let sat = Satellite(withTLE: tle)
            SatelliteElevationCurve(
                satellite: sat,
                // 2000 Broadway, Redwood City, CA 94063
                observerCoordinate: LatLonAlt(lat: 37.486743000691185, lon: -122.22655970246515, alt: 0),
                dateRange: calendar.startOfDay(for: Date())..<calendar.startOfDay(for: Date()).advanced(by: 7200)
            )
        }
    }
}
