//
//  SatelliteCatalog.swift
//  SatelliteCatalog
//
//  Created by Ben Lu on 6/23/21.
//

import SatelliteCatalog
import SQLite

extension SatelliteCatalog {
    enum SatCatTable {
        static var tableName: Table { Table("SatCat") }
        static var name: Expression<String> { Expression<String>("OBJECT_NAME") }
        static var objectID: Expression<String> { Expression<String>("OBJECT_ID") }
        static var noradCatID: Expression<Int> { Expression<Int>("NORAD_CAT_ID") }
        static var objectType: Expression<String> { Expression<String>("OBJECT_TYPE") }
        static var operationalStatusCode: Expression<String?> { Expression<String?>("OPS_STATUS_CODE") }
        static var owner: Expression<String> { Expression<String>("OWNER") }
        static var launchDate: Expression<String> { Expression<String>("LAUNCH_DATE") }
        static var launchSite: Expression<String> { Expression<String>("LAUNCH_SITE") }
        static var decayDate: Expression<String?> { Expression<String?>("DECAY_DATE") }
        static var period: Expression<Double?> { Expression<Double?>("PERIOD") }
        static var inclination: Expression<Double?> { Expression<Double?>("INCLINATION") }
        static var apogee: Expression<Double?> { Expression<Double?>("APOGEE") }
        static var perigee: Expression<Double?> { Expression<Double?>("PERIGEE") }
        static var rcs: Expression<Double?> { Expression<Double?>("RCS") }
        static var dataStatusCode: Expression<String?> { Expression<String?>("DATA_STATUS_CODE") }
        static var orbitCenter: Expression<String> { Expression<String>("ORBIT_CENTER") }
        static var orbitType: Expression<String> { Expression<String>("ORBIT_TYPE") }
    }

    enum UCSSatTable {
        static var tableName: Table { Table("UCS") }
        static var name: Expression<String> { Expression<String>("NameofSatelliteAlternateNames") }
        static var officialName: Expression<String> { Expression<String>("CurrentOfficialNameofSatellite") }
        static var countryOrOrgOfUNRegistry: Expression<String> { Expression<String>("Country/OrgofUNRegistry") }
        static var countryOfOperatorOrOwner: Expression<String> { Expression<String>("CountryofOperator/Owner") }
        static var operatorOrOwner: Expression<String> { Expression<String>("Operator/Owner") }
        static var users: Expression<String> { Expression<String>("Users") }
        static var purpose: Expression<String> { Expression<String>("Purpose") }
        static var detailedPurpose: Expression<String?> { Expression<String?>("DetailedPurpose") }
        static var classOfOrbit: Expression<String> { Expression<String>("ClassofOrbit") }
        static var typeOfOrbit: Expression<String?> { Expression<String?>("TypeofOrbit") }
        static var longitudeOfGEO: Expression<Double?> { Expression<Double?>("LongitudeofGEO(degrees)") }
        static var perigee: Expression<Double?> { Expression<Double?>("Perigee(km)") }
        static var apogee: Expression<Double?> { Expression<Double?>("Apogee(km)") }
        static var eccentricity: Expression<Double?> { Expression<Double?>("Eccentricity") }
        static var inclination: Expression<Double?> { Expression<Double?>("Inclination(degrees)") }
        static var period: Expression<Double?> { Expression<Double?>("Period(minutes)") }
        static var launchMass: Expression<Double?> { Expression<Double?>("LaunchMass(kg.)") }
        static var dryMass: Expression<Double?> { Expression<Double?>("DryMass(kg.)") }
        static var power: Expression<Double?> { Expression<Double?>("Power(watts)") }
        static var dateOfLaunch: Expression<String> { Expression<String>("DateofLaunch") }
        static var expectedLifetime: Expression<Double?> { Expression<Double?>("ExpectedLifetime(yrs.)") }
        static var contractor: Expression<String?> { Expression<String?>("Contractor") }
        static var countryOfContractor: Expression<String?> { Expression<String?>("CountryofContractor") }
        static var launchSite: Expression<String?> { Expression<String?>("LaunchSite") }
        static var launchVehicle: Expression<String> { Expression<String>("LaunchVehicle") }
        static var cosparID: Expression<String> { Expression<String>("COSPARNumber") }
        static var noradID: Expression<Int> { Expression<Int>("NORADNumber") }
        static var comments: Expression<String?> { Expression<String?>("Comments") }
        static var comments2: Expression<String?> { Expression<String?>("Comments2") }
        static var sourceUsedForOrbitalData: Expression<String?> { Expression<String?>("SourceUsedforOrbitalData") }
        static var source1: Expression<String?> { Expression<String?>("Source1") }
        static var source2: Expression<String?> { Expression<String?>("Source2") }
        static var source3: Expression<String?> { Expression<String?>("Source3") }
        static var source4: Expression<String?> { Expression<String?>("Source4") }
        static var source5: Expression<String?> { Expression<String?>("Source5") }
        static var source6: Expression<String?> { Expression<String?>("Source6") }
        static var source7: Expression<String?> { Expression<String?>("Source7") }
    }
}
