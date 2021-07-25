//
//  SatelliteForcastApp.swift
//  Shared
//
//  Created by Ben Lu on 5/28/21.
//

import SwiftUI
import SatelliteKit
import SatelliteForcastCore
import SwiftRex
import CombineRex
import CombineRextensions

@main
struct SatelliteForcastApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @StateObject var store = Store.shared.asObservableViewModel(initialState: .empty)

    var body: some Scene {
        WindowGroup {
            ViewProducer
                .satelliteOverview(viewModel: store)
                .view()
                .sheet(
                    isPresented: Binding<Bool>(
                        get: {
                            store.state.debugMenu.isDebugMenuVisible
                        },
                        set: { newValue in
                            store.dispatch(.debugMenu(.toggleDebugMenu(newValue)))
                        }
                    ),
                    onDismiss: nil,
                    content: {
                        ViewProducer<Void, DebugMenu>.debugMenu(viewModel: store)
                            .view()
                    }
                )
                .onAppear {
                    store.dispatch(.timer(.start))
                    store.dispatch(.coreLocation(.requestAuthorization))
                }
                .onReceive(NotificationCenter.default.publisher(for: .deviceDidShakeNotification)) { _ in
                    #if DEBUG
                    store.dispatch(.debugMenu(.toggleDebugMenu(true)))
                    #endif
                }
        }
    }
}
