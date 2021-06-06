//
//  TLELoaderState.swift
//  SatelliteForcast
//
//  Created by Ben Lu on 6/4/21.
//

import Foundation
import SatelliteForcastCore
import SatelliteKit

enum TLECategory: Equatable, Hashable {
    case brightest100

    var url: URL {
        switch self {
        case .brightest100:
            return URL(string: "https://www.celestrak.com/NORAD/elements/visual.txt")!
        }
    }
}

struct TLELoaderState: Equatable {
    var tles: [TLECategory: [TLE]] = [:]
    var standaloneTLEs: [TLE] = []

    static var empty: TLELoaderState {
        return TLELoaderState()
    }
}
