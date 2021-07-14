//
//  Result+Convenience.swift
//  SatelliteForcastCore
//
//  Created by Ben Lu on 7/5/21.
//

import Foundation

extension Result {
    public var successValue: Success? {
        switch self {
        case let .success(success):
            return success
        case .failure(_):
            return nil
        }
    }
}
