//
//  UCSSat.swift
//  SatelliteForecastCore
//
//  Created by Ben Lu on 6/23/21.
//

import Foundation

/// The primitive reflecting the data in https://www.ucsusa.org/resources/satellite-database.
/// This catalog only contains active satellites orbiting the Earth. Note that the data may be not up to date.
public struct UCSSat {
    /// Name of the satellite and alternative names
    public let name: String

    /// Current official name of the satellite
    public let officialName: String

    public let countryOrOrgOfUNRegistry: String

    public let countryOfOperatorOrOwner: String

    public let operatorOrOwner: String

    /// Satellite users, for example Commercial, Civil, Military, Government of any combinations of above.
    public let users: String

    public let purpose: String

    public let detailedPurpose: String?

    public enum ClassOfOrbit: String {
        case elliptical = "Elliptical"
        case LEO
        case MEO
        case GEO
    }

    public let classOfOrbit: ClassOfOrbit

    public let typeOfOrbit: String?

    public let longitudeOfGEO: Double?

    public let perigee: Double?

    public let apogee: Double?

    public let eccentricity: Double?

    public let inclination: Double?

    public let period: Double?

    public let launchMass: Double?

    public let dryMass: Double?

    public let power: Double?

    public let dateOfLaunch: Date

    public let expectedLifetime: Double?

    public let contractor: String?

    public let countryOfContractor: String?

    public let launchSite: String?

    public let launchVehicle: String

    public let cosparID: String

    public let noradID: Int

    public let comments: [String]

    public let sourceUsedForOrbitalData: String?

    public let sources: [String]

    public init(
        name: String,
        officialName: String,
        countryOrOrgOfUNRegistry: String,
        countryOfOperatorOrOwner: String,
        operatorOrOwner: String,
        users: String,
        purpose: String,
        detailedPurpose: String?,
        classOfOrbit: UCSSat.ClassOfOrbit,
        typeOfOrbit: String?,
        longitudeOfGEO: Double?,
        perigee: Double?,
        apogee: Double?,
        eccentricity: Double?,
        inclination: Double?,
        period: Double?,
        launchMass: Double?,
        dryMass: Double?,
        power: Double?,
        dateOfLaunch: Date,
        expectedLifetime: Double?,
        contractor: String?,
        countryOfContractor: String?,
        launchSite: String?,
        launchVehicle: String,
        cosparID: String,
        noradID: Int,
        comments: [String],
        sourceUsedForOrbitalData: String?,
        sources: [String]
    ) {
        self.name = name
        self.officialName = officialName
        self.countryOrOrgOfUNRegistry = countryOrOrgOfUNRegistry
        self.countryOfOperatorOrOwner = countryOfOperatorOrOwner
        self.operatorOrOwner = operatorOrOwner
        self.users = users
        self.purpose = purpose
        self.detailedPurpose = detailedPurpose
        self.classOfOrbit = classOfOrbit
        self.typeOfOrbit = typeOfOrbit
        self.longitudeOfGEO = longitudeOfGEO
        self.perigee = perigee
        self.apogee = apogee
        self.eccentricity = eccentricity
        self.inclination = inclination
        self.period = period
        self.launchMass = launchMass
        self.dryMass = dryMass
        self.power = power
        self.dateOfLaunch = dateOfLaunch
        self.expectedLifetime = expectedLifetime
        self.contractor = contractor
        self.countryOfContractor = countryOfContractor
        self.launchSite = launchSite
        self.launchVehicle = launchVehicle
        self.cosparID = cosparID
        self.noradID = noradID
        self.comments = comments
        self.sourceUsedForOrbitalData = sourceUsedForOrbitalData
        self.sources = sources
    }
}

extension UCSSat: Equatable {}
