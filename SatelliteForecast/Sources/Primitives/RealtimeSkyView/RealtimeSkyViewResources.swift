//
//  RealtimeSkyViewResources.swift
//  BTree
//
//  Created by Ben Lu on 4/7/22.
//

import BTree

public struct RealtimeSkyViewResources {
    /// The propagation results containing the satellite snapshot ordered by the time when next check should take place.
    public var results: BTree<Double, RealtimePropagationResult> = .init()
    public var displayResults: [RealtimePropagationResult] = []
    public var isRealtimeSkyViewActive: Bool = false
    public var isPropagatingEphemerides: Bool = false

    public init(
        results: BTree<Double, RealtimePropagationResult> = .init(),
        displayResults: [RealtimePropagationResult] = [],
        isRealtimeSkyViewActive: Bool = false,
        isPropagatingEphemerides: Bool = false
    ) {
        self.results = results
        self.displayResults = displayResults
        self.isRealtimeSkyViewActive = isRealtimeSkyViewActive
        self.isPropagatingEphemerides = isPropagatingEphemerides
    }
}

extension RealtimeSkyViewResources: Equatable {}
