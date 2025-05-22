//
//  SpectralType.swift
//  Orbits
//
//  Created by Ben Lu on 2/11/17.
//  Copyright © 2017 Ben Lu. All rights reserved.
//

import Foundation
import SQLite

public struct SpectralType: CustomStringConvertible {
    public let rawType: String
    public var description: String {
        return rawType
    }

    public let type: String
    public let subType: Double?
    public let luminosityClass: String?

    /// Spectral peculiarities of the star
    ///
    /// seealso: [Stellar Classification](https://en.wikipedia.org/wiki/Stellar_classification)
    public let peculiarities: String?

    private var shortenedSpectralType: String {
        return "\(type)\(subType != nil ? String(subType!) : String())\(luminosityClass ?? String())"
    }

    /// The effective temperature
    public var temperature: Double {
        guard let subType = subType else {
            return 0
        }

        let fractionSubtype = "\(type)\(String(format: "%.1f", subType))%"
        let integerSubtype = "\(type)\(String(Int(subType)))%"
        if let row = try? StarryNight.db.pluck(
            StarryNight.Spectral.table.select(StarryNight.Spectral.temp).where(StarryNight.Spectral.spectralType.like(fractionSubtype))
        ) {
            return row[StarryNight.Spectral.temp] + 273.15
        } else if let row = try? StarryNight.db.pluck(
            StarryNight.Spectral.table.select(StarryNight.Spectral.temp).where(StarryNight.Spectral.spectralType.like(integerSubtype))
        ) {
            return row[StarryNight.Spectral.temp] + 273.15
        }
        // This is rare but may happen
        return 0
    }

    public init?(_ str: String) {
        if str.isEmpty {
            return nil
        }
        self.rawType = str
        // some spectral type may have ambiguity e.g. G8III/IV
        // will remove anything after /
        let unambiguousType = String(str.prefix(while: { $0 != "/" }))
        
        let pattern = #/^(\w)(\d(?:\.\d)?)?((?:IV|Iab|Ia\+?|Ib|I+|V)(?:-(?:IV|Iab|Ia\+?|Ib|I+|V))?)(.*)/#
        
        if let match = try? pattern.firstMatch(in: unambiguousType),
           ["O", "B", "A", "F", "G", "K", "M"].contains(String(match.1)) {
            self.type = String(match.1)
            subType = doubleOrEmpty(match.2)
            luminosityClass = String(match.3)
            peculiarities = nilIfEmpty(String(match.4))
        } else {
            return nil
        }
    }
}

private func doubleOrEmpty(_ str: (any StringProtocol)?) -> Double? {
    if let str = str, let dblValue = Double(str) {
        return dblValue
    }
    return nil
}

private func nilIfEmpty(_ str: String?) -> String? {
    if let str = str, str.isEmpty {
        return nil
    }
    return str
}
