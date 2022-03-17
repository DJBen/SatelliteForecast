//
//  Elements+Preview.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/6/22.
//

import SatelliteKit

extension Elements {
    #if DEBUG

    static func loadLocalData(category: SatelliteCategory) throws -> [Elements] {
        guard let filepath = Bundle.main.path(forResource: category.localFilename, ofType: "txt") else {
            fatalError("No local file available")
        }
        let contents = try String(contentsOfFile: filepath)
        return try Elements.load(chunk: contents)
    }

    #endif
}
