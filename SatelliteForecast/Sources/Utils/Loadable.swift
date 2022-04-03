//
//  Loadable.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 3/6/22.
//

import Foundation

public enum Loadable<Content, ErrorType: LocalizedError> {
    case notLoaded
    case loading
    case loaded(Content)
    case failed(ErrorType)

    public var content: Content? {
        switch self {
        case .notLoaded, .loading, .failed(_):
            return nil
        case .loaded(let content):
            return content
        }
    }
}

extension Loadable {
    public func map<NewContent>(_ transform: (Content) -> NewContent) -> Loadable<NewContent, ErrorType> {
        switch self {
        case .notLoaded:
            return .notLoaded
        case .loading:
            return .loading
        case .failed(let error):
            return .failed(error)
        case .loaded(let content):
            return .loaded(transform(content))
        }
    }

    public func flatMap<NewContent>(_ transform: (Content) -> NewContent?) -> Loadable<NewContent, ErrorType> {
        switch self {
        case .notLoaded:
            return .notLoaded
        case .loading:
            return .loading
        case .failed(let error):
            return .failed(error)
        case .loaded(let content):
            if let newContent = transform(content) {
                return .loaded(newContent)
            } else {
                return .notLoaded
            }
        }
    }
}

extension Loadable: Equatable where Content: Equatable {
    public static func == (lhs: Loadable<Content, ErrorType>, rhs: Loadable<Content, ErrorType>) -> Bool {
        switch (lhs, rhs) {
        case (.notLoaded, .notLoaded):
            return true
        case (.loading, .loading):
            return true
        case (.loaded(let content1), .loaded(let content2)):
            return content1 == content2
        case (.failed(_), .failed(_)):
            return true
        default:
            return false
        }
    }
}
