//
//  BTree+Convenience.swift
//  SatelliteForcastCore
//
//  Created by Ben Lu on 6/8/21.
//

import Foundation
import BTree

extension BidirectionalCollection {
    /// Split the map into a list of submaps based on the criteria between every neighboring elements. The splitted subarray will never be empty.
    /// - Parameter shouldSplit: A block passing two elements and expecting a boolean. If the block evaluates to `true`, the map will be split between these two elements.
    /// - Returns: Split the map into a list of submaps based on evaluations of each pair of elements.
    public func split(shouldSplit: (Element, Element) -> Bool) -> [[Element]] {
        guard !isEmpty else {
            return []
        }
        var results = [[Element]]()
        var fromIndex: Index = startIndex

        for i in indices where i < index(before: endIndex) {
            let e1 = self[i]
            let e2 = self[index(after: i)]
            if shouldSplit(e1, e2) {
                results.append(Array(self[fromIndex...i]))
                fromIndex = index(after: i)
            }
        }

        results.append(Array(self[fromIndex..<endIndex]))
        return results
    }
}

extension Map {
    /// Split the map into a list of submaps based on the criteria between every neighboring elements. The resulting subtrees will
    /// guarantee to have at least one element.
    /// - Parameter shouldSplit: A block passing two elements and expecting a boolean. If the block evaluates to `true`, the
    /// map will be split between these two elements.
    /// - Returns: Split the map into a list of submaps based on evaluations of each pair of elements.
    public func split(shouldSplit: (Element, Element) -> Bool) -> [Map<Key, Value>] {
        guard !isEmpty else {
            return []
        }
        var results = [Map<Key, Value>]()
        var fromIndex: Map<Key, Value>.Index = startIndex

        for i in indices where i < index(before: endIndex) {
            let e1 = self[i]
            let e2 = self[index(after: i)]
            if shouldSplit(e1, e2) {
                results.append(self[fromIndex...i])
                fromIndex = index(after: i)
            }
        }

        results.append(self[fromIndex..<endIndex])
        return results
    }
}
