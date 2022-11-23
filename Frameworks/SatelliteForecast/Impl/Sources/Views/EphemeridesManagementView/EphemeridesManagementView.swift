//
//  EphemeridesManagementView.swift
//  ActivityView
//
//  Created by Ben Lu on 11/22/22.
//

import SwiftUI
import SatelliteForecast

struct EphemeridesManagementView: View {
    @State private var resources: [EphemerideResource] = []

    init() {}

    @ViewBuilder private func cell(resource: EphemerideResource) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(
                    resource.fileName
                )
                .font(.headline)
                .foregroundColor(Color(UIColor.label))

                Spacer()

                if let formattedCreationDate = resource.formattedCreationDate {
                    Text(
                        formattedCreationDate
                    )
                    .font(.subheadline)
                    .foregroundColor(Color(UIColor.secondaryLabel))
                }
            }

            if let formattedSize = resource.formattedSize {
                Text(
                    formattedSize
                )
                .font(.subheadline)
                .foregroundColor(Color(UIColor.secondaryLabel))
            }

            if let comment = resource.comment {
                Text(
                    comment
                )
                .font(.caption)
                .foregroundColor(Color(UIColor.tertiaryLabel))
            }
        }
    }

    private func fetchEphemerideResources() throws -> [EphemerideResource] {
        let temporaryDirectory = FileManager.default.temporaryDirectory
        let fileNames = try FileManager.default.contentsOfDirectory(atPath: temporaryDirectory.path()).filter { ($0 as NSString).pathExtension == "txt" }
        let attributes = try fileNames.map { fileName in
            try FileManager.default.attributesOfItem(atPath: (temporaryDirectory.path() as NSString).appendingPathComponent(fileName))
        }
        return zip(fileNames, attributes).map { (fileName, attributes) in
            EphemerideResource(
                fileName: fileName,
                size: attributes[.size] as? UInt64,
                creationDate: attributes[.creationDate] as? Date
            )
        }
    }

    var body: some View {
        Group {
            if resources.isEmpty {
                Text(
                    EphemeridesManagementView.emptyText
                )
                .foregroundColor(Color(UIColor.secondaryLabel))
                .padding(.horizontal, 16)
            } else {
                List {
                    ForEach(resources, id: \.fileName) { resource in
                        cell(
                            resource: resource
                        )
                    }
                    .onDelete { indexSet in
                        let resourcesToDelete = Array(indexSet).map { resources[$0] }
                        let temporaryDirectory = FileManager.default.temporaryDirectory

                        for resource in resourcesToDelete {
                            do {
                                try FileManager.default.removeItem(
                                    atPath: (temporaryDirectory.path() as NSString).appendingPathComponent(resource.fileName)
                                )
                            } catch {

                            }
                        }
                        self.resources = (try? fetchEphemerideResources()) ?? []
                    }
                }
            }
        }
        .navigationTitle("Ephemerides")
        .task {
            self.resources = (try? fetchEphemerideResources()) ?? []
        }
    }
}

extension EphemeridesManagementView {
    static let emptyText: String = NSLocalizedString(
        "EphemeridesManagementView.emptyText",
        tableName: nil,
        bundle: .satelliteForecastImplResourcesBundle,
        value: "No downloaded satellite ephemerides",
        comment: "The empty text for the satellite ephemerides"
    )
}
