//
//  CancellableFuture.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 2/16/22.
//

import Combine

public struct CancellableFuture<Output, Failure: Error>: Publisher {
    public typealias Promise = (Result<Output, Failure>) -> Void

    public class CancellationRef {
        public var isCancelled = false
    }

    let attemptToFulfill: (@escaping Promise, CancellationRef) -> Void
    let cancellationRef: CancellationRef

    public init(attemptToFulfill: @escaping (@escaping Promise, CancellationRef) -> Void) {
        self.attemptToFulfill = attemptToFulfill
        self.cancellationRef = CancellationRef()
    }

    public func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
        Deferred {
            Future { promise in
                attemptToFulfill(promise, cancellationRef)
            }
        }
        .handleEvents(
            receiveCancel: {
                cancellationRef.isCancelled = true
            }
        )
        .receive(subscriber: subscriber)
    }
}
