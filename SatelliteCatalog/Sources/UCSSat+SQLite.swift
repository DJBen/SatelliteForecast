//
//  UCSSat+SQLite.swift
//  SatelliteCatalog
//
//  Created by Ben Lu on 6/24/21.
//

import Foundation
import SQLite
import SatelliteKit

extension UCSSat {
    typealias Table = SatelliteCatalog.UCSSatTable

    init(row: Row) {
        self.init(
            name: try! row.get(Table.name),
            officialName: try! row.get(Table.officialName),
            countryOrOrgOfUNRegistry: try! row.get(Table.countryOrOrgOfUNRegistry),
            countryOfOperatorOrOwner: try! row.get(Table.countryOfOperatorOrOwner),
            operatorOrOwner: try! row.get(Table.operatorOrOwner),
            users: try! row.get(Table.users),
            purpose: try! row.get(Table.purpose),
            detailedPurpose: try! row.get(Table.detailedPurpose),
            classOfOrbit: ClassOfOrbit(rawValue: try! row.get(Table.classOfOrbit))!,
            typeOfOrbit: try! row.get(Table.typeOfOrbit),
            longitudeOfGEO: try! row.get(Table.longitudeOfGEO),
            perigee: try! row.get(Table.perigee),
            apogee: try! row.get(Table.apogee),
            eccentricity: try! row.get(Table.eccentricity),
            inclination: try! row.get(Table.inclination),
            period: try! row.get(Table.period),
            launchMass: try! row.get(Table.launchMass),
            dryMass: try! row.get(Table.dryMass),
            power: try! row.get(Table.power),
            dateOfLaunch: Date(julianDate: try! row.get(Table.dateOfLaunch) + 2415020),
            expectedLifetime: try! row.get(Table.expectedLifetime),
            contractor: try! row.get(Table.contractor),
            countryOfContractor: try! row.get(Table.countryOfContractor),
            launchSite: try! row.get(Table.launchSite),
            launchVehicle: try! row.get(Table.launchVehicle),
            cosparID: try! row.get(Table.cosparID),
            noradID: try! row.get(Table.noradID),
            comments: try! row.get(Table.comments).map { [$0] } ?? [],
            sourceUsedForOrbitalData: try! row.get(Table.sourceUsedForOrbitalData),
            sources: {
                let sources = [
                    Table.source1,
                    Table.source2,
                    Table.source3,
                    Table.source4,
                    Table.source5,
                    Table.source6,
                    Table.source7
                ]
                return sources.compactMap { try! row.get($0) }
            }()
        )
    }

    /// Find the satellite with a specified NORAD CAT ID and return its info
    /// - Parameter noradCatID: The NORAD CAT ID>
    /// - Returns: The satellite info.
    public static func with(noradCatID: Int) -> UCSSat? {
        let query = Table.tableName.filter(Table.noradID == noradCatID)
        return try! SatelliteCatalog.DB.pluck(query).flatMap(UCSSat.init(row:))
    }
}
