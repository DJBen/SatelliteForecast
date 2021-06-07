//
//  SatelliteSnapshot.swift
//  SatelliteForcastCore
//
//  Created by Ben Lu on 6/2/21.
//

import Foundation
import SatelliteKit

/// A snapshot of the satellite of a specific date, coordinate, velocity and whether
/// if it is illuminated by sunlight.
public struct SatelliteSnapshot {
    public let date: Date
    public let position: AziEleDst
    public let isIlluminated: Bool

    /// The sun's elevation, ranging from -90 to 90 degrees.
    public let sunElevation: Double

    public init(
        date: Date,
        position: AziEleDst,
        isIlluminated: Bool,
        sunElevation: Double
    ) {
        self.date = date
        self.position = position
        self.isIlluminated = isIlluminated
        self.sunElevation = sunElevation
    }
}

extension SatelliteSnapshot: Equatable {}

extension Array {
    public func split(belongsToSameGroup: (Element, Element) -> Bool) -> [[Element]] {
        guard let firstElement = first else {
            return [[]]
        }
        var results = [[Element]]()
        var segment = [firstElement]
        for i in startIndex..<endIndex - 1 {
            if belongsToSameGroup(self[i], self[i + 1]) {
                segment.append(self[i + 1])
            } else {
                results.append(segment)
                segment = [self[i + 1]]
            }
        }
        results.append(segment)
        return results
    }
}
