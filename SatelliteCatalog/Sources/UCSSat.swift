//
//  UCSSat.swift
//  SatelliteForcastCore
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

    public let typeOfOrbit: String

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

    public let launchSite: String

    public let launchVehicle: String

    public let cosparID: String

    public let noradID: Int

    public let comments: [String]

    public let sourceUsedForOrbitalData: String?

    public let sources: [String]
}

extension UCSSat: Equatable {}
