//
//  DebugMenu.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 7/24/21.
//

import SwiftUI
@preconcurrency import SwiftRex
@preconcurrency import CombineRex
@preconcurrency import CombineRextensions
import SatelliteForecast
@preconcurrency import SatelliteKit

public struct DebugMenuState: Equatable, AppStateMappable {
    var trueJulianDate: Double
    var config: DebugMenuConfig
    var pendingNotifications: [UNNotificationRequest]
    var deliveredNotifications: [UNNotification]
    var fcmToken: String?

    public static func project(appState state: AppState) -> DebugMenuState {
        DebugMenuState(
            trueJulianDate: Date().julianDate,
            config: state.debugMenu,
            pendingNotifications: state.notificationResources.pendingNotifications,
            deliveredNotifications: state.notificationResources.deliveredNotifications,
            fcmToken: state.fcmToken
        )
    }

    public static func apply(appState: inout AppState, state: DebugMenuState) {
        appState.debugMenu = state.config
        appState.notificationResources.pendingNotifications = state.pendingNotifications
        appState.notificationResources.deliveredNotifications = state.deliveredNotifications
    }
}

public struct DebugMenu: View {
    @ObservedObject var viewModel: ObservableViewModel<DebugMenuAction, DebugMenuState?>
    @State var dateWithinPicker: Date
    @State var showCopySuccess: Bool = false

    public init(
        viewModel: ObservableViewModel<DebugMenuAction, DebugMenuState?>
    ) {
        self.viewModel = viewModel
        if let offset = viewModel.state?.config.mockedOffset {
            self._dateWithinPicker = State(initialValue: Date().addingTimeInterval(offset * TimeConstants.day2sec))
        } else {
            self._dateWithinPicker = State(initialValue: Date())
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
                        viewModel.dispatch(.toggleFreezeTime(newValue))
                    }
                )
                .animation()
            ) {
                Text("Freeze time")
            }

            Toggle(
                isOn: Binding<Bool>(
                    get: {
                        state.config.mockedOffsetOn
                    },
                    set: { newValue in
                        viewModel.dispatch(.toggleMockedOffset(newValue))
                    }
                )
                .animation()
            ) {
                Text("Mock date and time")
            }

            if state.config.mockedOffsetOn {
                DatePicker(
                    "",
                    selection: $dateWithinPicker.animation()
                )

                HStack {
                    Spacer()
                    Button("Update time offset") {
                        viewModel.dispatch(.setMockedDateOffset(dateWithinPicker.julianDate - state.trueJulianDate))
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
                Text(request.content.title)
                    .font(.headline)
                    .foregroundColor(Color(UIColor.label))
                Spacer()
            }
            
            Text(request.content.body)
                .font(.caption)
                .foregroundColor(Color(UIColor.label))
            
            if let deliveredDate = deliveredDate {
                Text("Delivered at \(deliveredDate.formatted())")
                    .font(.caption)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.secondary)
            }
            
            if let calendarTrigger = request.trigger as? UNCalendarNotificationTrigger {
                Text(calendarTrigger.dateComponents.description)
                    .font(.caption)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.secondary)
            } else if let timeIntervalTrigger = request.trigger as? UNTimeIntervalNotificationTrigger {
                Text("Time interval \(timeIntervalTrigger.timeInterval.formatted())")
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
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("FCM Token")
                                    .font(.headline)
                                if let fcmToken = state.fcmToken {
                                    Text(fcmToken)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(nil)
                                } else {
                                    Text("No FCM token")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            if state.fcmToken != nil {
                                Button("Copy") {
                                    if let fcmToken = state.fcmToken {
                                        UIPasteboard.general.string = fcmToken
                                        showCopySuccess = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                            showCopySuccess = false
                                        }
                                    }
                                }
                            }
                        }
                        
                        if showCopySuccess {
                            Text("Copied to clipboard")
                                .font(.caption2)
                                .foregroundColor(.green)
                                .animation(.easeInOut(duration: 0.3), value: showCopySuccess)
                        }
                    }
                } header: {
                    Text("Device Information")
                }
                
                Section {
                    timeSectionContent
                } header: {
                    Text("Time control")
                } footer: {
                    if let frozenAt = state.config.frozenAt {
                        Text("Time frozen at \(Date(julianDate: frozenAt).formatted(date: .long, time: .standard))")
                    } else if state.config.mockedOffsetOn {
                        Text("Mock time \(Date(julianDate: state.trueJulianDate + state.config.mockedOffset).formatted(date: .long, time: .standard))\nOffset \(state.config.mockedOffset.formatted()) JD")
                    } else {
                        Text("Real time \(Date(julianDate: state.trueJulianDate).formatted(date: .long, time: .standard))")
                    }
                }

                Section {
                    Toggle(
                        isOn: Binding<Bool>(
                            get: {
                                state.config.rapidNotificationDelivery
                            },
                            set: { newValue in
                                viewModel.dispatch(.toggleRapidNotificationDelivery(newValue))
                            }
                        )
                        .animation()
                    ) {
                        Text("Deliver notifications 10 seconds after scheduled")
                    }
                }

                Section {
                    Button("Deep link to ISS (special)") {
                        viewModel.dispatch(.triggerPassDeepLink(category: .iss, noradIndex: 25544))
                    }
                    Button("Deep link to Hubble (brightest 100)") {
                        viewModel.dispatch(.triggerPassDeepLink(category: .brightest100, noradIndex: 20580))
                    }
                } header: {
                    Text("Test deep link")
                }

                Section {
                    pendingNotificationsContent
                } header: {
                    Text("Pending notifications")
                }

                Section {
                    deliveredNotificationsContent
                } header: {
                    Text("Delivered notifications")
                }
                
                Section {
                    Button("Reset All Onboarding") {
                        viewModel.dispatch(.resetOnboarding)
                    }
                    
                    Button("Reset Main Onboarding") {
                        viewModel.dispatch(.resetMainOnboarding)
                    }
                    
                    Button("Reset Pass List Onboarding") {
                        viewModel.dispatch(.resetAllPassesOnboarding)
                    }
                } header: {
                    Text("Onboarding")
                }
            }
            .navigationTitle("Debug Menu")
            .onAppear {
                dateWithinPicker = Date(julianDate: state.trueJulianDate + (state.config.mockedOffsetOn ? state.config.mockedOffset : 0))
                viewModel.dispatch(.fetchNotifications)
            }
        }   
    }
}

extension ViewProducer where Context == Void, ProducedView == DebugMenu {
    public static func debugMenu<S: StoreType>(viewModel: S) -> ViewProducer where S.ActionType == AppAction, S.StateType == AppState {
        ViewProducer<Context, ProducedView> { context in
            DebugMenu(
                viewModel: viewModel.projection(
                    action: AppAction.debugMenu,
                    state: DebugMenuState.project(appState:)
                )
                .asObservableViewModel(initialState: nil, emitsValue: .whenDifferent)
            )
        }
    }
}
