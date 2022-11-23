//
//  EphemerideTextBrowserView.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 11/22/22.
//

import SwiftUI

struct EphemerideTextBrowserView: View {
    let resource: EphemerideResource

    @State var textResult: Result<String, Error>?

    var body: some View {
        Group {
            if let result = textResult {
                switch result {
                case .success(let text):
                    TextEditor(
                        text: .constant(text)
                    )
                    .autocorrectionDisabled()
                    .font(.body.monospaced())
                case .failure(let failure):
                    Text(
                        failure.localizedDescription
                    )
                    .font(.body)
                    .foregroundColor(Color(UIColor.secondaryLabel))
                    .padding(.horizontal, 16)
                }
            } else {
                ProgressView("Loading...")
            }
        }
        .navigationTitle(resource.fileName)
        .toolbar {
            ToolbarItem(
                placement: .primaryAction
            ) {
                Button {
                    UIApplication.shared.open(URL(string: "https://celestrak.org/NORAD/documentation/tle-fmt.php")!)
                } label: {
                    Image(systemName: "questionmark.circle")
                }
            }

            if case .success(let text) = textResult {
                ToolbarItem(
                    placement: .primaryAction
                ) {
                    ShareLink(
                        item: text,
                        subject: nil,
                        message: Text(
                            String(
                                format: NSLocalizedString(
                                    "EphemerideTextBrowserView.shareLink.message",
                                    tableName: nil,
                                    bundle: .satelliteForecastImplResourcesBundle,
                                    value: "Share %@ satellite ephemerides",
                                    comment: "The message of the share link in ephemeride text browser view"
                                ),
                                resource.fileName
                            )
                        )
                    ) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .task {
            do {
                self.textResult = .success(try String(contentsOfFile: resource.fullPath))
            } catch {
                self.textResult = .failure(error)
            }
        }
    }
}
