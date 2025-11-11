//
//  SatelliteCategory+Impl.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 4/1/22.
//

import Foundation
import SatelliteForecast

extension SatelliteCategory {
    public var url: URL {
        switch self {
        case .iss:
            return URL(string: "https://celestrak.org/NORAD/elements/gp.php?CATNR=25544&FORMAT=TLE")!
        case .tianhe:
            return URL(string: "https://celestrak.org/NORAD/elements/gp.php?CATNR=48274&FORMAT=TLE")!
        case .brightest100:
            return URL(string: "https://celestrak.com/NORAD/elements/gp.php?GROUP=visual&FORMAT=tle")!
        case .last30DayLaunches:
            return URL(string: "https://celestrak.com/NORAD/elements/gp.php?GROUP=last-30-days&FORMAT=tle")!
        case .active:
            return URL(string: "https://celestrak.com/NORAD/elements/gp.php?GROUP=active&FORMAT=tle")!
        }
    }

    public var localFilename: String {
        switch self {
        case .iss:
            return "25544"
        case .tianhe:
            return "48274"
        case .brightest100:
            return "visual"
        case .last30DayLaunches:
            return "elements-new"
        case .active:
            return "active"
        }
    }

    public func cachedFileURL(fileManager: FileManager = .default) -> URL {
        fileManager.temporaryDirectory
            .appendingPathComponent(localFilename)
            .appendingPathExtension("txt")
    }

    public func removeCachedElements(fileManager: FileManager = .default) {
        let url = cachedFileURL(fileManager: fileManager)
        try? fileManager.removeItem(at: url)
    }
}
