//
//  BTree+Convenience.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 6/8/21.
//

import Foundation
import BTree

public enum Inclusivity {
    case disjoint
    case includesFirstElementInNextGroup
    case includesSecondElementsInPreviousGroup
}

extension BidirectionalCollection {
    /// Split the list into a list of sublists based on the criteria between every neighboring elements. The splitted subarray will never be empty.
    /// - Parameter shouldSplit: A block passing two elements and expecting a boolean. If the block evaluates to `true`, the map will be split between these two elements.
    /// - Returns: Split the map into a list of sublists based on evaluations of each pair of elements.
    public func split(inclusivity: Inclusivity = .disjoint, shouldSplit: (Element, Element) -> Bool) -> [[Element]] {
        guard !isEmpty else {
            return []
        }
        var results = [[Element]]()
        var fromIndex: Index = startIndex

        for i in indices where i < index(before: endIndex) {
            let e1 = self[i]
            let e2 = self[index(after: i)]
            if shouldSplit(e1, e2) {
                switch inclusivity {
                case .disjoint:
                    results.append(Array(self[fromIndex...i]))
                    fromIndex = index(after: i)
                case .includesFirstElementInNextGroup:
                    results.append(Array(self[fromIndex...i]))
                    fromIndex = i
                case .includesSecondElementsInPreviousGroup:
                    results.append(Array(self[fromIndex...index(after: i)]))
                    fromIndex = index(after: i)
                }
            }
        }

        results.append(Array(self[fromIndex..<endIndex]))
        return results
    }
}
