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

enum DebugMenuAction {
    case toggleDebugMenu(_ isVisible: Bool)

    case toggleFreezeTime(_ isOn: Bool)
    case toggleMockedOffset(_ isOn: Bool)
    case setMockedDateOffset(_ offset: Double)
}

struct DebugMenuConfig: Equatable {
    var isDebugMenuVisible: Bool = false
    var frozenAt: Double?
    var mockedOffsetOn: Bool = false

    /// Offset in days between the real julian date and the mocked julian date. Positive value means mocked date is in the future,
    /// while negative value means mocked date is in the past.
    var mockedOffset: Double = 0

    static var empty: DebugMenuConfig {
        return DebugMenuConfig()
    }
}

struct DebugMenuState: Equatable {
    var trueJulianDate: Double
    var config: DebugMenuConfig

    static func project(state: AppState) -> DebugMenuState {
        DebugMenuState(
            trueJulianDate: state.satelliteLoaderState.currentDate,
            config: state.debugMenu
        )
    }
}

struct DebugMenu: View {
    @ObservedObject var viewModel: ObservableViewModel<DebugMenuAction, DebugMenuState?>
    @State var dateWithinPicker: Date = Date()

    @ViewBuilder private func unwrapState<Content: View>(@ViewBuilder content: (DebugMenuState) -> Content) -> some View {
        if let state = viewModel.state {
            content(state)
        }
    }

    @ViewBuilder private var timeSection: some View {
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
            ) {
                Text("Mock date and time")
            }

            if state.config.mockedOffsetOn {
                DatePicker(
                    "",
                    selection: $dateWithinPicker
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

    var body: some View {
        unwrapState { state in
            NavigationView {
                Form {
                    Section {
                        timeSection
                    } header: {
                        EmptyView()
                    } footer: {
                        if let frozenAt = state.config.frozenAt {
                            Text("Time frozen at \(Date(julianDate: frozenAt).formatted(date: .long, time: .standard))")
                        } else if state.config.mockedOffsetOn {
                            Text("Mock time \(Date(julianDate: state.trueJulianDate + state.config.mockedOffset).formatted(date: .long, time: .standard))\nOffset \(state.config.mockedOffset.formatted()) JD")
                        } else {
                            Text("Real time \(Date(julianDate: state.trueJulianDate).formatted(date: .long, time: .standard))")
                        }
                    }

                }
                .navigationTitle("Debug Menu")
            }
            .onAppear {
                dateWithinPicker = Date(julianDate: state.trueJulianDate + (state.config.mockedOffsetOn ? state.config.mockedOffset : 0))
            }
        }
    }
}

extension ViewProducer where Context == Void, ProducedView == DebugMenu {
    static func debugMenu<S: StoreType>(viewModel: S) -> ViewProducer where S.ActionType == AppAction, S.StateType == AppState {
        ViewProducer<Context, ProducedView> { context in
            DebugMenu(
                viewModel: viewModel.projection(
                    action: AppAction.debugMenu,
                    state: DebugMenuState.project(state:)
                )
                .asObservableViewModel(initialState: nil)
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
                    config: .empty
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
                    }
                }
            )
        )
    }
}
#endif
