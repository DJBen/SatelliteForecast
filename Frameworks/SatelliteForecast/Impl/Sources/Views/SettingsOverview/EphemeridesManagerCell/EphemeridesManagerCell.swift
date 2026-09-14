//
//  EphemeridesManagerCell.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 11/22/22.
//

import SwiftUI

public struct EphemeridesManagerCell: View {
    @Environment(\.colorScheme) private var colorScheme

    @Environment(\.ephemerisDirectory) private var directory

    @State var resources: [EphemerideResource] = []

    init() {}

    private var background: some View { AppTheme.surface }

    private func fetchEphemerideResources() throws -> [EphemerideResource] {
        let temporaryDirectory = directory
        let fileNames = try FileManager.default.contentsOfDirectory(atPath: temporaryDirectory.path()).filter { ($0 as NSString).pathExtension == "txt" }
        let attributes = try fileNames.map { fileName in
            try FileManager.default.attributesOfItem(atPath: (temporaryDirectory.path() as NSString).appendingPathComponent(fileName))
        }
        return zip(fileNames, attributes).map { (fileName, attributes) in
            EphemerideResource(
                fileName: fileName,
                fullPath: (temporaryDirectory.path() as NSString).appendingPathComponent(fileName),
                size: attributes[.size] as? UInt64,
                modificationDate: attributes[.modificationDate] as? Date
            )
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "archivebox")
                    .font(.headline)
                    .foregroundColor(Color(UIColor.label))

                Text(EphemeridesManagerCell.title(fileCount: resources.count))
                    .font(.headline)
                    .foregroundColor(Color(UIColor.label))

                Spacer()
            }

            Text(
                EphemeridesManagerCell.description
            )
            .font(.subheadline)
            .multilineTextAlignment(.leading)
            .foregroundColor(AppTheme.muted)
        }
        .padding()
        .background(background)
        .overlay(RoundedRectangle(cornerRadius: AppTheme.cardRadius).stroke(AppTheme.border, lineWidth: 1))
        .clipShape(
            RoundedRectangle(
                cornerRadius: AppTheme.cardRadius,
                style: .continuous
            )
        )
        .task {
            do {
                self.resources = try fetchEphemerideResources()
            } catch {
                print(error)
            }
        }
    }
}

extension EphemeridesManagerCell {
    static func title(fileCount: Int) -> String {
        String(
            format: NSLocalizedString(
                "SatelliteOverview.ephemeridesManagerCell.title",
                tableName: nil,
                bundle: .module,
                value: "%#@ephemerideFileCount@",
                comment: "The title for ephemerides manager cell"
            ),
            fileCount
        )
    }

    static var description: String {
        NSLocalizedString(
            "SatelliteOverview.ephemeridesManagerCell.description",
            tableName: nil,
            bundle: .module,
            value: "View and manage downloaded raw satellite ephemerides.",
            comment: "The description for ephemerides manager cell"
        )
    }
}
