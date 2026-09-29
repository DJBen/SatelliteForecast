import FirebaseAppCheck
import FirebaseCore
import FirebaseMessaging
import Foundation
import SwiftUI

struct BrightnessReportTarget: Identifiable {
    let id = UUID()
    let noradID: UInt
    let name: String
    let observedAt = Date()
}

@MainActor
enum BrightnessReportUpload {
    struct Payload: Encodable {
        let id: String
        let noradID: UInt
        let magnitude: Double
        let observedAt: Double
        let installationID: String
        let fcmToken: String
    }

    static func send(target: BrightnessReportTarget, magnitude: Double) async throws {
        #if targetEnvironment(simulator)
        throw URLError(.notConnectedToInternet)
        #else
        guard NSClassFromString("XCTestCase") == nil,
              let project = FirebaseApp.app()?.options.projectID,
              let url = URL(string: "https://us-central1-\(project).cloudfunctions.net/report_satellite_brightness") else {
            throw URLError(.badURL)
        }
        let identityKey = "brightnessReportInstallationID"
        let installationID = UserDefaults.standard.string(forKey: identityKey) ?? UUID().uuidString
        UserDefaults.standard.set(installationID, forKey: identityKey)
        let fcmToken = try await Messaging.messaging().token()
        let attestation = try await AppCheck.appCheck().token(forcingRefresh: false)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(attestation.token, forHTTPHeaderField: "X-Firebase-AppCheck")
        request.httpBody = try JSONEncoder().encode(Payload(id: target.id.uuidString,
            noradID: target.noradID, magnitude: magnitude,
            observedAt: target.observedAt.timeIntervalSince1970, installationID: installationID, fcmToken: fcmToken))
        let (_, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 204 else { throw URLError(.badServerResponse) }
        #endif
    }
}

struct BrightnessReportSheet: View {
    let target: BrightnessReportTarget
    @Environment(\.dismiss) private var dismiss
    @State private var magnitude = 2.5
    @State private var submittedMagnitude: Double?
    @State private var sending = false
    @State private var failed = false
    @State private var succeeded = false

    private var guidance: String {
        let descriptions = [
            "Very bright — comparable to the brightest stars, such as Vega.",
            "Bright — stands out among most nearby stars.",
            "Moderately bright — roughly comparable to Polaris.",
            "Moderate — easier to see away from bright city lights.",
            "Dim — best seen under a dark sky with adjusted eyes.",
            "Faint — may be difficult to see without a clear, dark sky."
        ]
        return AppLocalization.text(descriptions[Int(magnitude.rounded())])
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text(target.name).font(.title3.weight(.semibold))
                Text("Estimate the brightness you observed. Lower magnitudes are brighter.", bundle: .module)
                    .font(.subheadline).foregroundStyle(AppTheme.muted)
                Text(String.localizedStringWithFormat(AppLocalization.text("Magnitude %.1f"), magnitude))
                    .font(.title2.monospacedDigit().weight(.semibold))
                Slider(value: $magnitude, in: 0...5, step: 0.1) {
                    Text("Magnitude", bundle: .module)
                } minimumValueLabel: { Text(verbatim: "0") } maximumValueLabel: { Text(verbatim: "5") }
                    .disabled(sending || submittedMagnitude != nil)
                Text(guidance).font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: 52, alignment: .topLeading)
                Text("Visibility depends on sky conditions. Report only what you actually observed.", bundle: .module)
                    .font(.caption).foregroundStyle(AppTheme.muted)
                if failed {
                    Text("Could not send your report. Check your connection and try again.", bundle: .module)
                        .font(.subheadline).foregroundStyle(.red)
                }
                Button {
                    let value = submittedMagnitude ?? magnitude
                    submittedMagnitude = value
                    sending = true
                    failed = false
                    Task {
                        do {
                            try await BrightnessReportUpload.send(target: target, magnitude: value)
                            succeeded = true
                        } catch { failed = true }
                        sending = false
                    }
                } label: {
                    HStack {
                        if sending { ProgressView() }
                        Text(AppLocalization.text(failed ? "Retry" : "Report"))
                    }.frame(maxWidth: .infinity, minHeight: 44)
                        .font(.headline)
                        .foregroundStyle(AppTheme.text)
                }
                .buttonStyle(.glass).controlSize(.large).disabled(sending)
                Spacer(minLength: 0)
            }
            .padding(24)
            .background(AppTheme.background)
            .navigationTitle(AppLocalization.text("Report brightness"))
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppLocalization.text("Cancel")) { dismiss() }.disabled(sending)
                }
            }
            .alert(AppLocalization.text("Report received"), isPresented: $succeeded) {
                Button(AppLocalization.text("Done")) { dismiss() }
            } message: {
                Text("Thank you for reporting your observation.", bundle: .module)
            }
        }
        .foregroundStyle(AppTheme.text).tint(AppTheme.accent)
        .presentationDetents([.large]).presentationDragIndicator(.visible)
        .interactiveDismissDisabled(sending)
        .analyticsScreen(.brightnessReport)
    }
}
