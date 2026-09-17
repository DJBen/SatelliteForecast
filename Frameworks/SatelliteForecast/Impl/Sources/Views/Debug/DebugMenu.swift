//
//  DebugMenu.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 7/24/21.
//

import SwiftUI
import SatelliteForecast
@preconcurrency import SatelliteKit

public struct DebugMenuState: Equatable {
    var trueJulianDate: Double
    var config: DebugMenuConfig
    var pendingNotifications: [UNNotificationRequest]
    var deliveredNotifications: [UNNotification]
    var fcmToken: String?


}

public struct DebugMenu: View {
    @State var viewModel: DebugModel
    @State var dateWithinPicker: Date
    @State var showCopySuccess: Bool = false
    @Environment(\.dismiss) private var dismiss

    public init(
        viewModel: DebugModel
    ) {
        self.viewModel = viewModel
        if let offset = viewModel.state?.config.mockedOffset {
            self._dateWithinPicker = State(initialValue: Date(julianDate: (viewModel.state?.trueJulianDate ?? Date().julianDate) + offset))
        } else {
            self._dateWithinPicker = State(initialValue: Date(julianDate: viewModel.state?.trueJulianDate ?? Date().julianDate))
        }
    }

    @ViewBuilder private func unwrapState<Content: View>(@ViewBuilder content: (DebugMenuState) -> Content) -> some View {
        if let state = viewModel.state {
            content(state)
        }
    }

    @ViewBuilder private var timeSectionContent: some View {
        unwrapState { state in
            Toggle(
                isOn: Binding<Bool>(
                    get: {
                        state.config.frozenAt != nil
                    },
                    set: { newValue in
                        viewModel.send(.toggleFreezeTime(newValue))
                    }
                )
                .animation()
            ) {
                Text(verbatim: "Freeze time")
            }

            Toggle(
                isOn: Binding<Bool>(
                    get: {
                        state.config.mockedOffsetOn
                    },
                    set: { newValue in
                        viewModel.send(.toggleMockedOffset(newValue))
                    }
                )
                .animation()
            ) {
                Text(verbatim: "Mock date and time")
            }

            if state.config.mockedOffsetOn {
                DatePicker(
                    "",
                    selection: $dateWithinPicker.animation()
                )

                HStack {
                    Spacer()
                    Button {
                        viewModel.send(.setMockedDateOffset(dateWithinPicker.julianDate - state.trueJulianDate))
                    } label: {
                        Text(verbatim: "Update time offset")
                    }
                }
            }
        }
    }
    
    @ViewBuilder private func notificationView(
        request: UNNotificationRequest,
        deliveredDate: Date? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(verbatim: request.content.title)
                    .font(.headline)
                    .foregroundColor(Color(UIColor.label))
                Spacer()
            }
            
            Text(verbatim: request.content.body)
                .font(.caption)
                .foregroundColor(Color(UIColor.label))
            
            if let deliveredDate = deliveredDate {
                Text(verbatim: "Delivered at \(deliveredDate.formatted())")
                    .font(.caption)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.secondary)
            }
            
            if let calendarTrigger = request.trigger as? UNCalendarNotificationTrigger {
                Text(verbatim: calendarTrigger.dateComponents.description)
                    .font(.caption)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.secondary)
            } else if let timeIntervalTrigger = request.trigger as? UNTimeIntervalNotificationTrigger {
                Text(verbatim: "Time interval \(timeIntervalTrigger.timeInterval.formatted())")
                    .font(.caption)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder private var pendingNotificationsContent: some View {
        unwrapState { state in
            List {
                ForEach(state.pendingNotifications, id: \.identifier) { request in
                    notificationView(request: request)
                }
            }
        }
    }
    
    @ViewBuilder private var deliveredNotificationsContent: some View {
        unwrapState { state in
            List {
                ForEach(state.deliveredNotifications, id: \.request.identifier) { notification in
                    notificationView(request: notification.request, deliveredDate: notification.date)
                }
            }
        }
    }

    public var body: some View {
        unwrapState { state in
            NavigationStack {
                Form {
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(verbatim: "FCM Token")
                                        .font(.headline)
                                    if let fcmToken = state.fcmToken {
                                        Text(verbatim: fcmToken)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(nil)
                                    } else {
                                        Text(verbatim: "No FCM token")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                if state.fcmToken != nil {
                                    Button {
                                        if let fcmToken = state.fcmToken {
                                            UIPasteboard.general.string = fcmToken
                                            showCopySuccess = true
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                                showCopySuccess = false
                                            }
                                        }
                                    } label: {
                                        Text(verbatim: "Copy")
                                    }
                                }
                            }

                            if showCopySuccess {
                                Text(verbatim: "Copied to clipboard")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                                    .animation(.easeInOut(duration: 0.3), value: showCopySuccess)
                            }
                        }
                    } header: {
                        Text(verbatim: "Device Information")
                    }

                    Section {
                        timeSectionContent
                    } header: {
                        Text(verbatim: "Time control")
                    } footer: {
                        if let frozenAt = state.config.frozenAt {
                            Text(verbatim: "Time frozen at \(Date(julianDate: frozenAt).formatted(date: .long, time: .standard))")
                        } else if state.config.mockedOffsetOn {
                            Text(verbatim: "Mock time \(Date(julianDate: state.trueJulianDate + state.config.mockedOffset).formatted(date: .long, time: .standard))\nOffset \(state.config.mockedOffset.formatted()) JD")
                        } else {
                            Text(verbatim: "Real time \(Date(julianDate: state.trueJulianDate).formatted(date: .long, time: .standard))")
                        }
                    }

                    Section {
                        Button {
                            viewModel.send(.resetOnboarding)
                        } label: {
                            Text(verbatim: "Reset All Onboarding")
                        }

                        Button {
                            viewModel.send(.resetMainOnboarding)
                        } label: {
                            Text(verbatim: "Reset Main Onboarding")
                        }

                        Button {
                            viewModel.send(.resetHomeOnboarding)
                        } label: {
                            Text(verbatim: "Reset Home Screen Onboarding")
                        }

                        Button {
                            viewModel.send(.resetAllPassesOnboarding)
                        } label: {
                            Text(verbatim: "Reset Pass List Onboarding (includes Sky Chart Tutorial)")
                        }

                        Button {
                            viewModel.send(.resetOrientationGuidance)
                        } label: {
                            Text(verbatim: "Reset Lift Your iPhone Guidance")
                        }
                    } header: {
                        Text(verbatim: "Onboarding")
                    }

                    Section {
                        Toggle(
                            isOn: Binding<Bool>(
                                get: {
                                    state.config.rapidNotificationDelivery
                                },
                                set: { newValue in
                                    viewModel.send(.toggleRapidNotificationDelivery(newValue))
                                }
                            )
                            .animation()
                        ) {
                            Text(verbatim: "Deliver notifications 10 seconds after scheduled")
                        }
                    }

                    Section {
                        Button {
                            viewModel.send(.triggerPassDeepLink(category: .iss, noradIndex: 25544))
                        } label: {
                            Text(verbatim: "Deep link to ISS (special)")
                        }
                        Button {
                            viewModel.send(.triggerPassDeepLink(category: .brightest100, noradIndex: 20580))
                        } label: {
                            Text("Deep link to Hubble (brightest 100)")
                        }
                    } header: {
                        Text(verbatim: "Test deep link")
                    }

                    Section {
                        pendingNotificationsContent
                    } header: {
                        Text(verbatim: "Pending notifications")
                    }

                    Section {
                        deliveredNotificationsContent
                    } header: {
                        Text(verbatim: "Delivered notifications")
                    }
                }
                .modifier(AppSurface())
        .navigationTitle(Text(verbatim: "Debug Menu"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Text(verbatim: "Close")
                        }
                    }
                }
                .onAppear {
                    dateWithinPicker = Date(julianDate: state.trueJulianDate + (state.config.mockedOffsetOn ? state.config.mockedOffset : 0))
                    viewModel.send(.fetchNotifications)
                }
            }
        }
    }
}
