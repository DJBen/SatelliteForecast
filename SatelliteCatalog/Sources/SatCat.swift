//
//  SatCat.swift
//  SatelliteCatalog
//
//  Created by Ben Lu on 6/23/21.
//

import Foundation

/// A primitive reflecting the Celestrak satellite catalog https://celestrak.com/satcat/search.php.
/// It include all objects that has ever been launched, including interplantary ones.
public struct SatCat {
    public let name: String
    public let cosparID: String
    public let noradID: Int

    public enum ObjectType: String {
        case payload = "PAY"
        case rocketBody = "R/B"
        case debris = "DEB"
        case unknown = "UNK"
    }

    public let objectType: ObjectType

    public enum OperationalStatus: String {
        case operational = "+"
        case nonoperational = "-"
        /// Partially fulfilling primary mission or secondary mission(s)
        case partiallyOperational = "P"
        /// Previously operational satellite put into reserve status
        case backup = "B"
        /// New satellite awaiting full activation
        case spare = "S"
        case extendedMission = "X"
        case decayed = "D"
        case unknown = "?"
    }

    public let operationalStatus: OperationalStatus?

    public let owner: Owner

    public let launchDate: Date

    public let launchSite: LaunchSite

    public let decayDate: Date?

    /// Orbital period [minutes]
    public let period: Double?

    /// Inclination [degrees]
    public let inclination: Double?

    /// Apogee Altitude [kilometers]
    public let apogee: Double?

    /// Perigee Altitude [kilometers]
    public let perigee: Double?

    /// Radar Cross Section [meters2]; blank if no data available
    public let rcs: Double?

    public enum OrbitCenter {
        case asteroid
        case comet
        case earth
        case earthLagrange(Int)
        case earthMoonBarycenter
        case jupiter
        case mars
        case mercury
        case moon
        case neptune
        case pluto
        case saturn
        case solarSystemEscape
        case sun
        case uranus
        case venus
        case docked(noradID: Int)

        public init?(code: String) {
            switch code {
            case "AS":
                self = .asteroid
            case "CO":
                self = .comet
            case "EA":
                self = .earth
            case "EL1", "EL2", "EL3", "EL4", "EL5":
                self = .earthLagrange(Int(String(code.last!))!)
            case "EM":
                self = .earthMoonBarycenter
            case "JU":
                self = .jupiter
            case "MA":
                self = .mars
            case "ME":
                self = .mercury
            case "MO":
                self = .moon
            case "NE":
                self = .neptune
            case "PL":
                self = .pluto
            case "SA":
                self = .saturn
            case "SS":
                self = .solarSystemEscape
            case "SU":
                self = .sun
            case "UR":
                self = .uranus
            case "VE":
                self = .venus
            default:
                if let noradCatID = Int(code) {
                    self = .docked(noradID: noradCatID)
                } else {
                    return nil
                }
            }
        }
    }

    public let orbitCenter: OrbitCenter

    public enum OrbitType {
        case orbit
        case landing
        case impact
        /// Docked to another object in the SATCAT
        case docked
        case roundtrip

        public init?(code: String) {
            switch code {
            case "ORB":
                self = .orbit
            case "LAN":
                self = .landing
            case "IMP":
                self = .impact
            case "DOC":
                self = .docked
            case "R/T":
                self = .roundtrip
            default:
                return nil
            }
        }
    }

    public let orbitType: OrbitType
}

extension SatCat: Equatable {}

extension SatCat.OrbitCenter: Equatable {}

extension SatCat.OrbitType: Equatable {}
