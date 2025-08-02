//
//  Constellation.swift
//  Orbits
//
//  Created by Ben Lu on 2/3/17.
//  Copyright © 2017 Ben Lu. All rights reserved.
//

import Foundation

public struct Constellation: Hashable, Sendable {
    public struct Line: CustomStringConvertible, Sendable {
        public let star1: Star
        public let star2: Star

        public var description: String {
            return "(\(star1) - \(star2))"
        }
        
        public init(star1: Star, star2: Star) {
            self.star1 = star1
            self.star2 = star2
        }
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(iAUName)
    }

    public static func ==(lhs: Constellation, rhs: Constellation) -> Bool {
        return lhs.iAUName == rhs.iAUName
    }

    public let name: String
    public let iAUName: String
    public let genitive: String

    public init(name: String, iAUName: String, genitive: String) {
        self.name = name
        self.iAUName = iAUName
        self.genitive = genitive
    }
}
