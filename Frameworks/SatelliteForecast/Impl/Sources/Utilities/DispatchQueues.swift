//
//  DispatchQueues.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 11/22/22.
//

import Foundation

let satellitePathRasterizationQueue: DispatchQueue = DispatchQueue(label: "satellite_path_rasterization")
let backgroundSkyRasterizationQueue: DispatchQueue = DispatchQueue(label: "background_sky_rasterization")
let elevationGraphRasterizationQueue: DispatchQueue = DispatchQueue(label: "elevation_graph_rasterization")
