//
//  EphemeridesManagerCell.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 11/22/22.
//

import SwiftUI

public struct EphemeridesManagerCell: View {
    @Environment(\.colorScheme) private var colorScheme

    @State var resources: [EphemerideResource] = []

    init() {}

    private var background: some View {
        var colors = [UIColor.systemCyan, UIColor.systemBlue]

        if colorScheme == .dark {
            colors = colors.map { $0.darken(by: 0.3) }
        } else {
            colors = colors.map { $0.darken(by: -0.3) }
        }

        return LinearGradient(
            gradient: Gradient(colors: colors.map(Color.init)),
            startPoint: UnitPoint(x: 0, y: 0),
            endPoint: UnitPoint(x: 1, y: 1)
        )
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
                fullPath: (temporaryDirectory.path() as NSString).appendingPathComponent(fileName),
                size: attributes[.size] as? UInt64,
                creationDate: attributes[.creationDate] as? Date
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
        }
        .padding()
        .background(background)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 8,
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
                bundle: .satelliteForecastImplResourcesBundle,
                value: "%#@ephemerideFileCount@",
                comment: "The title for ephemerides manager cell"
            ),
            fileCount
        )
    }
}
