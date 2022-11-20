//
//  DebugMenu.swift
//  SatelliteForecast
//
//  Created by Ben Lu on 7/24/21.
//

import SwiftUI
import SwiftRex
import CombineRex
import CombineRextensions
import SatelliteForecast
import SatelliteKit

public enum DebugMenuAction {
    case toggleDebugMenu(_ isVisible: Bool)

    case toggleFreezeTime(_ isOn: Bool)
    case toggleMockedOffset(_ isOn: Bool)
    case setMockedDateOffset(_ offset: Double)
    case toggleRapidNotificationDelivery(_ isOn: Bool)
    
    case fetchNotifications
    
    case triggerPassDeepLink(category: SatelliteCategory?, noradIndex: UInt)
}

public struct DebugMenuConfig: Equatable {
    public var isDebugMenuVisible: Bool = false
    public var frozenAt: Double?
    public var mockedOffsetOn: Bool = false
    public var rapidNotificationDelivery: Bool = false

    /// Offset in days between the real julian date and the mocked julian date. Positive value means mocked date is in the future,
    /// while negative value means mocked date is in the past.
    public var mockedOffset: Double = 0

    /// The julian date offset in effect.
    public var effectiveOffset: Double {
        mockedOffsetOn ? mockedOffset : 0
    }

    public init() {}
}

public struct DebugMenuState: Equatable {
    var trueJulianDate: Double
    var config: DebugMenuConfig
    var pendingNotifications: [UNNotificationRequest]
    var deliveredNotifications: [UNNotification]

    static func project(state: AppState) -> DebugMenuState {
        DebugMenuState(
            trueJulianDate: Date().julianDate,
            config: state.debugMenu,
            pendingNotifications: state.notificationResources.pendingNotifications,
            deliveredNotifications: state.notificationResources.deliveredNotifications
        )
    }

    static func apply(appState: inout AppState, state: DebugMenuState) {
        appState.debugMenu = state.config
        appState.notificationResources.pendingNotifications = state.pendingNotifications
        appState.notificationResources.deliveredNotifications = state.deliveredNotifications
    }
}

public struct DebugMenu: View {
    @ObservedObject var viewModel: ObservableViewModel<DebugMenuAction, DebugMenuState?>
    @State var dateWithinPicker: Date

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
                        viewModel.dispatch(.triggerPassDeepLink(category: nil, noradIndex: 25544))
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
                    state: DebugMenuState.project(state:)
                )
                .asObservableViewModel(initialState: nil, emitsValue: .whenDifferent)
            )
        }
    }
}

#if DEBUG
struct DebugMenu_Previews: PreviewProvider {
    static var previews: some View {
        DebugMenu(
            viewModel: .mock(
                state: DebugMenuState(
                    trueJulianDate: 2459420.60909,
                    config: .init(),
                    pendingNotifications: [
                        UNNotificationRequest(
                            identifier: "id1",
                            content: {
                                let content = UNMutableNotificationContent()
                                content.title = "ISS (ZARYA)"
                                content.body = "Body text"
                                return content
                            }(),
                            trigger: {
                                UNTimeIntervalNotificationTrigger(
                                    timeInterval: 10000,
                                    repeats: false
                                )
                            }()
                        )
                    ],
                    deliveredNotifications: []
                ),
                action: { action, source, state in
                    switch action {
                    case .toggleDebugMenu(_):
                        break

                    case let .toggleFreezeTime(isOn):
                        if isOn {
                            state?.config.frozenAt = Date().julianDate
                        } else {
                            state?.config.frozenAt = nil
                        }

                    case let .toggleMockedOffset(isOn):
                        state?.config.mockedOffsetOn = isOn

                    case let .setMockedDateOffset(offset):
                        state?.config.mockedOffset = offset
                        
                    case let .toggleRapidNotificationDelivery(isOn):
                        state?.config.rapidNotificationDelivery = isOn
                        
                    case .fetchNotifications:
                        break
                        
                    case .triggerPassDeepLink:
                        break
                    }
                }
            )
        )
    }
}
#endif
