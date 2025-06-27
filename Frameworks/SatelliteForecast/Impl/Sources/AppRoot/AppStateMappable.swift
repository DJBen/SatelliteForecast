//
//  AppStateMappable.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 2/8/22.
//

/// A protocol that defines a state that is mappable from the `AppState`.
public protocol AppStateMappable {
    static func project(appState: AppState) -> Self
    static func apply(appState: inout AppState, state: Self)
}
