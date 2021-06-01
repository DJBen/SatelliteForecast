//
//  StarryNight.swift
//  Graviton
//
//  Created by Sihao Lu on 8/12/17.
//  Copyright © 2017 Ben Lu. All rights reserved.
//

import Foundation
import SQLite

let db = try! Connection(Bundle.main.path(forResource: "stars", ofType: "sqlite3")!)
