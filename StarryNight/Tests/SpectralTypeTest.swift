//
//  SpectralTypeTest.swift
//  Graviton
//
//  Created by Sihao Lu on 8/26/17.
//  Copyright © 2017 Ben Lu. All rights reserved.
//

import XCTest
@testable import StarryNight
import Regex

final class SpectralTypeTest: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testMessSpectralTypeParsing() {
        let data = Star.magitudeLessThan(7).filter { $0.physicalInfo.rawSpectralType != nil }.map { ($0.identity.description, $0.physicalInfo.rawSpectralType!) }
        for (name, spectralType) in data {
            if spectralType.isEmpty {
                continue
            }
            // ignore extended spectral types
            if ["C", "W", "S", "Y", "J", "N"].contains(spectralType.first!) {
                continue
            }
            // ignore white dwarves
            if Regex("(d|D|sd).*").matches(spectralType) {
                continue
            }
            let spectral = SpectralType(spectralType)
            XCTAssertNotNil(spectral, "\(name)'s spectral type \(spectralType) cannot be parsed!")
            _ = spectral?.temperature
        }
    }

    func testIndividualCases() {
        SpectralType("F7.5IV-V")!.assertEqual(type: "F", subType: 7.5, luminosityClass: "IV-V")
        SpectralType("K0III")!.assertEqual(type: "K", subType: 0, luminosityClass: "III")
        SpectralType("G5")!.assertEqual(type: "G", subType: 5)
        SpectralType("G8III:")!.assertEqual(type: "G", subType: 8, luminosityClass: "III", pecularities: ":")
        SpectralType("M0/M1IIICNp")!.assertEqual(type: "M", subType: 0)
        SpectralType("B8Ia")!.assertEqual(type: "B", subType: 8, luminosityClass: "Ia")
        SpectralType("B1.5IV+...")!.assertEqual(type: "B", subType: 1.5, luminosityClass: "IV", pecularities: "+...")
    }

    func testTemperature() {
        XCTAssertEqual(SpectralType("O3V")!.temperature, 46000 + 273.15)
        XCTAssertEqual(SpectralType("B8Ia")!.temperature, 12500 + 273.15)
        XCTAssertEqual(SpectralType("M7.5V")!.temperature, 2600 + 273.15)
    }
}

extension SpectralType {
    func assertEqual(type: String, subType: Double?, luminosityClass: String? = nil, pecularities: String? = nil) {
        XCTAssertEqual(self.type, type)
        XCTAssertEqual(self.subType, subType)
        XCTAssertEqual(self.luminosityClass, luminosityClass)
        XCTAssertEqual(self.peculiarities, pecularities)
    }
}
