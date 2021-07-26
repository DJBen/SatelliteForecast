//
//  BTree+Equatable.swift
//  BTree+Equatable
//
//  Created by Ben Lu on 7/26/21.
//

import Foundation
import BTree

extension BTree: Equatable where Key: Equatable, Value: Equatable {}

extension BTree where Key: AdditiveArithmetic & SignedNumeric & Comparable {
    /// Return the value whose key is the closest to the given key based on arithmatic distance.
    /// - Parameter key: The key.
    /// - Returns: The value.
    func value(closestTo key: Key, within tolerance: Key? = nil) -> Value? {
        if isEmpty {
            return nil
        }

        func applyTolerance(_ element: (Key, Value)) -> (Key, Value)? {
            if let tolerance = tolerance {
                return abs(key - element.0) <= tolerance ? element : nil
            } else {
                return element
            }
        }

        let index = self.index(forInserting: key, at: .last)

        if index == startIndex {
            return applyTolerance(self[startIndex])?.1
        } else if index == endIndex{
            return applyTolerance(self.last!)?.1
        } else {
            let after = applyTolerance(self[index])
            let before = applyTolerance(self[self.index(before: index)])
            if let after = after, let before = before {
                return (after.0 - key > key - before.0) ? after.1 : before.1
            } else if let after = after {
                return after.1
            } else if let before = before {
                return before.1
            } else {
                return nil
            }
        }
    }
}
