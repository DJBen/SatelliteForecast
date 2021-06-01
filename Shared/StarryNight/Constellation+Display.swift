//
//  Constellation+Display.swift
//  Graviton
//
//  Created by Sihao Lu on 3/4/17.
//  Copyright © 2017 Ben Lu. All rights reserved.
//

//public extension EquatorialCoordinate {
//    public var constellation: Constellation {
//        let precessed = self.precessed(from: 2000, to: 1850)
//        let raHours = precessed.rightAscension.wrappedValue
//        let decDegrees = precessed.declination.wrappedValue
//        let query = borders.filter(dbLowRa <= raHours && dbHighRa > raHours && dbLowDec <= decDegrees).order(dbLowDec.desc).limit(1)
//        let row = try! db.pluck(query)!
//        return Constellation.iau(try! row.get(dbBorderCon))!
//    }
//}
