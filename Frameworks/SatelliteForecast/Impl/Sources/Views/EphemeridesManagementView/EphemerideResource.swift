//
//  EphemerideResource.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 11/22/22.
//

import Foundation
import SatelliteForecast

struct EphemerideResource: Equatable, Hashable, Codable, Sendable {
    let fileName: String
    let fullPath: String
    let size: UInt64?
    let modificationDate: Date?

    var fileNameWithoutExtension: String {
        (fileName as NSString).deletingPathExtension
    }

    var comment: String? {
        if fileNameWithoutExtension == SatelliteCategory.brightest100.localFilename {
            return NSLocalizedString(
                "EphemeridesManagementView.comment.visual",
                tableName: nil,
                bundle: .module,
                value: "Ephemerides for the brightest 100 satellites.",
                comment: "The comment text for the visual (brightest 100) satellites file"
            )
        } else if fileNameWithoutExtension == SatelliteCategory.last30DayLaunches.localFilename {
            return NSLocalizedString(
                "EphemeridesManagementView.comment.last30Days",
                tableName: nil,
                bundle: .module,
                value: "Ephemerides for the new launches within last 30 days.",
                comment: "The comment text for the last 30 days satellites file"
            )
        } else if fileNameWithoutExtension == SatelliteCategory.active.localFilename {
            return NSLocalizedString(
                "EphemeridesManagementView.comment.active",
                tableName: nil,
                bundle: .module,
                value: "Ephemerides for all active satellites.",
                comment: "The comment text for the last 30 days satellites file"
            )
        } else {
            return nil
        }
    }

    var formattedSize: String? {
        guard let size = size else {
            return nil
        }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }

    @MainActor private static let durationFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        formatter.formattingContext = .beginningOfSentence
        return formatter
    }()

    @MainActor
    var formattedModificationDate: String? {
        guard let modificationDate = modificationDate else {
            return nil
        }

        return Self.durationFormatter.string(for: modificationDate)
    }
}
