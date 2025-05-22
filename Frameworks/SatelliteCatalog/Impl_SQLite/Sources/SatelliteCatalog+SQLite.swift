//
//  SatelliteCatalog.swift
//  SatelliteCatalog
//
//  Created by Ben Lu on 6/23/21.
//

import Foundation
import SatelliteCatalog
import SQLite

extension SatelliteCatalog {
    static let DB = try! Connection(Bundle.module.path(forResource: "satellites", ofType: "sqlite")!)

    enum SatCatTable {
        static let tableName = Table("SatCat")
        static let name = Expression<String>("OBJECT_NAME")
        static let objectID = Expression<String>("OBJECT_ID")
        static let noradCatID = Expression<Int>("NORAD_CAT_ID")
        static let objectType = Expression<String>("OBJECT_TYPE")
        static let operationalStatusCode = Expression<String?>("OPS_STATUS_CODE")
        static let owner = Expression<String>("OWNER")
        static let launchDate = Expression<String>("LAUNCH_DATE")
        static let launchSite = Expression<String>("LAUNCH_SITE")
        static let decayDate = Expression<String?>("DECAY_DATE")
        static let period = Expression<Double?>("PERIOD")
        static let inclination = Expression<Double?>("PERIOD")
        static let apogee = Expression<Double?>("APOGEE")
        static let perigee = Expression<Double?>("PERIGEE")
        static let rcs = Expression<Double?>("RCS")
        static let dataStatusCode = Expression<String?>("DATA_STATUS_CODE")
        static let orbitCenter = Expression<String>("ORBIT_CENTER")
        static let orbitType = Expression<String>("ORBIT_TYPE")
    }

    enum UCSSatTable {
        static let tableName = Table("UCS")
        static let name = Expression<String>("NameofSatelliteAlternateNames")
        static let officialName = Expression<String>("CurrentOfficialNameofSatellite")
        static let countryOrOrgOfUNRegistry = Expression<String>("Country/OrgofUNRegistry")
        static let countryOfOperatorOrOwner = Expression<String>("CountryofOperator/Owner")
        static let operatorOrOwner = Expression<String>("Operator/Owner")
        static let users = Expression<String>("Users")
        static let purpose = Expression<String>("Purpose")
        static let detailedPurpose = Expression<String?>("DetailedPurpose")
        static let classOfOrbit = Expression<String>("ClassofOrbit")
        static let typeOfOrbit = Expression<String?>("TypeofOrbit")
        static let longitudeOfGEO = Expression<Double?>("LongitudeofGEO(degrees)")
        static let perigee = Expression<Double?>("Perigee(km)")
        static let apogee = Expression<Double?>("Apogee(km)")
        static let eccentricity = Expression<Double?>("Eccentricity")
        static let inclination = Expression<Double?>("Inclination(degrees)")
        static let period = Expression<Double?>("Period(minutes)")
        static let launchMass = Expression<Double?>("LaunchMass(kg.)")
        static let dryMass = Expression<Double?>("DryMass(kg.)")
        static let power = Expression<Double?>("Power(watts)")
        static let dateOfLaunch = Expression<String>("DateofLaunch")
        static let expectedLifetime = Expression<Double?>("ExpectedLifetime(yrs.)")
        static let contractor = Expression<String?>("Contractor")
        static let countryOfContractor = Expression<String?>("CountryofContractor")
        static let launchSite = Expression<String?>("LaunchSite")
        static let launchVehicle = Expression<String>("LaunchVehicle")
        static let cosparID = Expression<String>("COSPARNumber")
        static let noradID = Expression<Int>("NORADNumber")
        static let comments = Expression<String?>("Comments")
        static let comments2 = Expression<String?>("Comments2")
        static let sourceUsedForOrbitalData = Expression<String?>("SourceUsedforOrbitalData")
        static let source1 = Expression<String?>("Source1")
        static let source2 = Expression<String?>("Source2")
        static let source3 = Expression<String?>("Source3")
        static let source4 = Expression<String?>("Source4")
        static let source5 = Expression<String?>("Source5")
        static let source6 = Expression<String?>("Source6")
        static let source7 = Expression<String?>("Source7")
    }
}
