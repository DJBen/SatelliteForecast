//
//  Directions.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 4/4/22.
//

import Foundation

public enum Directions {
    public static let north = NSLocalizedString(
        "Directions.north",
        tableName: nil,
        bundle: .module,
        value: "north",
        comment: ""
    )

    public static let northEast = NSLocalizedString(
        "Directions.northeast",
        tableName: nil,
        bundle: .module,
        value: "northeast",
        comment: ""
    )

    public static let east = NSLocalizedString(
        "Directions.east",
        tableName: nil,
        bundle: .module,
        value: "east",
        comment: ""
    )

    public static let southeast = NSLocalizedString(
        "Directions.southeast",
        tableName: nil,
        bundle: .module,
        value: "southeast",
        comment: ""
    )

    public static let south = NSLocalizedString(
        "Directions.south",
        tableName: nil,
        bundle: .module,
        value: "south",
        comment: ""
    )

    public static let southwest = NSLocalizedString(
        "Directions.southwest",
        tableName: nil,
        bundle: .module,
        value: "southwest",
        comment: ""
    )

    public static let west = NSLocalizedString(
        "Directions.west",
        tableName: nil,
        bundle: .module,
        value: "west",
        comment: ""
    )

    public static let northwest = NSLocalizedString(
        "Directions.northwest",
        tableName: nil,
        bundle: .module,
        value: "northwest",
        comment: ""
    )

    public static let angles = [north, northEast, east, southeast, south, southwest, west, northwest, north]
}
