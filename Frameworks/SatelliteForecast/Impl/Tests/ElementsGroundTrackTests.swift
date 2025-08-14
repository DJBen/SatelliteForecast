//
//  ElementsGroundTrackTests.swift
//  SatelliteForecastImpl-Unit-Tests
//
//  Created by Ben Lu on 4/3/22.
//

import XCTest
@preconcurrency import SatelliteKit
import SatelliteForecast
@testable import SatelliteForecastImpl

class ElementsGroundTrackTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testGroundTrack() throws {
        let elements = try! Elements(
            raw: """
            ISS (ZARYA)
            1 25544U 98067A   21152.11066515  .00000451  00000-0  16375-4 0  9992
            2 25544  51.6453  62.2423 0003364  52.3737  88.5313 15.48937685286109
            """
        )

        let formatter = ISO8601DateFormatter()

        let groundTrack = try! elements.generateGroundTrack(
            julianDateRange: formatter.date(from: "2021-06-02T21:35:30+0800")!.julianDate...formatter.date(from: "2021-06-02T21:50:30+0800")!.julianDate,
            interval: 60 * TimeConstants.sec2day
        )

        XCTAssertEqual(
            groundTrack,
            [
                DateCoordinate(julianDate: 2459368.066319444, coordinate: LatLonAlt(-13.238089671080688, 309.25153827286107, 422.5968579612263)),
                DateCoordinate(julianDate: 2459368.0670138886, coordinate: LatLonAlt(-10.224384030514303, 311.5057887915509, 421.6899341550352)),
                DateCoordinate(julianDate: 2459368.067708333, coordinate: LatLonAlt(-7.190652158516908, 313.7136832182422, 420.87231930984944)),
                DateCoordinate(julianDate: 2459368.0684027774, coordinate: LatLonAlt(-4.142954195647172, 315.88960471817904, 420.15175610917595)),
                DateCoordinate(julianDate: 2459368.069097222, coordinate: LatLonAlt(-1.087101610699552, 318.0474538177087, 419.53420076039674)),
                DateCoordinate(julianDate: 2459368.069791666, coordinate: LatLonAlt(1.9712311688796595, 320.2008584464832, 419.0237424299794)),
                DateCoordinate(julianDate: 2459368.070486111, coordinate: LatLonAlt(5.0264018143737195, 322.3633846127125, 418.62255774676396)),
                DateCoordinate(julianDate: 2459368.0711805555, coordinate: LatLonAlt(8.072686002352858, 324.54873978593355, 418.33090271869423)),
                DateCoordinate(julianDate: 2459368.071875, coordinate: LatLonAlt(11.104181348831137, 326.7709917837695, 418.1471383188091)),
                DateCoordinate(julianDate: 2459368.0725694443, coordinate: LatLonAlt(14.114684798382747, 329.0447747660737, 418.0677944495883)),
                DateCoordinate(julianDate: 2459368.0732638887, coordinate: LatLonAlt(17.097570589530527, 331.3855032952193, 418.0876666327331)),
                DateCoordinate(julianDate: 2459368.073958333, coordinate: LatLonAlt(20.045652854214392, 333.8095826613015, 418.1999450340554)),
                DateCoordinate(julianDate: 2459368.0746527775, coordinate: LatLonAlt(22.95103137790133, 336.33460989645965, 418.39637270545336)),
                DateCoordinate(julianDate: 2459368.075347222, coordinate: LatLonAlt(25.804917401827915, 338.9795524167292, 418.66742964952573)),
                DateCoordinate(julianDate: 2459368.0760416663, coordinate: LatLonAlt(28.5974373051848, 341.7648821857409, 419.00253882159905)),
                DateCoordinate(julianDate: 2459368.0767361107, coordinate: LatLonAlt(31.31741392187695, 344.71263021324074, 419.3902897951748))
            ]
        )
    }
}
