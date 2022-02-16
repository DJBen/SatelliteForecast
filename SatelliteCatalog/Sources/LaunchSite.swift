//
//  LaunchSite.swift
//  SatelliteCatalog
//
//  Created by Ben Lu on 6/23/21.
//

import Foundation

public struct LaunchSite {
    public init(code: String) {
        self.code = code
    }

    public let code: String
    
    public var fullName: String? {
        switch code {
        case "AFETR": return "Air Force Eastern Test Range, Florida, USA"
        case "AFWTR": return "Air Force Western Test Range, California, USA"
        case "CAS": return "Canaries Airspace"
        case "DLS": return "Dombarovskiy Launch Site, Russia"
        case "ERAS": return "Eastern Range Airspace"
        case "FRGUI": return "Europe's Spaceport, Kourou, French Guiana"
        case "HGSTR": return "Hammaguira Space Track Range, Algeria"
        case "JSC": return "Jiuquan Space Center, PRC"
        case "KODAK": return "Kodiak Launch Complex, Alaska, USA"
        case "KSCUT": return "Uchinoura Space Center (Formerly Kagoshima Space Center—University of Tokyo, Japan)"
        case "KWAJ": return "US Army Kwajalein Atoll (USAKA)"
        case "KYMSC": return "Kapustin Yar Missile and Space Complex, Russia"
        case "NSC": return "Naro Space Complex, Republic of Korea"
        case "PLMSC": return "Plesetsk Missile and Space Complex, Russia"
        case "RLLB": return "Rocket Lab Launch Base"
        case "SEAL": return "Sea Launch Platform (mobile)"
        case "SEMLS": return "Semnan Satellite Launch Site, Iran"
        case "SMTS": return "Shahrud Missile Test Site, Iran"
        case "SNMLP": return "San Marco Launch Platform, Indian Ocean (Kenya)"
        case "SRILR": return "Satish Dhawan Space Centre, India (Formerly Sriharikota Launching Range)"
        case "SUBL": return "Submarine Launch Platform (mobile)"
        case "SVOBO": return "Svobodnyy Launch Complex, Russia"
        case "TAISC": return "Taiyuan Space Center, PRC"
        case "TANSC": return "Tanegashima Space Center, Japan"
        case "TYMSC": return "Tyuratam Missile and Space Center, Kazakhstan (Also known as Baikonur Cosmodrome)"
        case "UNK": return "Unknown"
        case "VOSTO": return "Vostochny Cosmodrome, Russia"
        case "WLPIS": return "Wallops Island, Virginia, USA"
        case "WOMRA": return "Woomera, Australia"
        case "WRAS": return "Western Range Airspace"
        case "WSC": return "Wenchang Satellite Launch Site, PRC"
        case "XICLF": return "Xichang Launch Facility, PRC"
        case "YAVNE": return "Yavne Launch Facility, Israel"
        case "YUN": return "Yunsong Launch Site (Sohae Satellite Launching Station), Democratic People's Republic of Korea"
        default:
            return nil
        }
    }
}

extension LaunchSite: Equatable {}
