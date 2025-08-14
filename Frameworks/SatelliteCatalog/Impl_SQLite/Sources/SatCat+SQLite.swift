//
//  SatCat+SQLite.swift
//  SatelliteCatalog
//
//  Created by Ben Lu on 6/23/21.
//

import Foundation
import SatelliteCatalog
import SQLite

private let dateFormatter: DateFormatter = {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "YYYY-MM-dd"
    return dateFormatter
}()

extension SatCat {
    typealias Table = SatelliteCatalog.SatCatTable

    init(row: Row) throws {
        self.init(
            name: try row.get(Table.name),
            cosparID: try row.get(Table.objectID),
            noradID: try row.get(Table.noradCatID),
            objectType: ObjectType(rawValue: try row.get(Table.objectType))!,
            operationalStatus: try row.get(Table.operationalStatusCode).flatMap(OperationalStatus.init(rawValue:)),
            owner: Owner(code: try row.get(Table.owner)),
            launchDate: dateFormatter.date(from: try row.get(Table.launchDate))!,
            launchSite: LaunchSite(code: try row.get(Table.launchSite)),
            decayDate: try row.get(Table.decayDate).flatMap(dateFormatter.date(from:)),
            period: try row.get(Table.period),
            inclination: try row.get(Table.inclination),
            apogee: try row.get(Table.apogee),
            perigee: try row.get(Table.perigee),
            rcs: try row.get(Table.rcs),
            orbitCenter: OrbitCenter(code: try row.get(Table.orbitCenter))!,
            orbitType: OrbitType(code: try row.get(Table.orbitType))!
        )
    }

    /// Find the satellite with a specified NORAD CAT ID and return its info
    /// - Parameter noradCatID: The NORAD CAT ID>
    /// - Returns: The satellite info.
    public static func with(noradCatID: Int) throws -> SatCat? {
        let query = Table.tableName.filter(Table.noradCatID == noradCatID)
        return try SatelliteCatalog.DB.pluck(query).flatMap(SatCat.init(row:))
    }
}
