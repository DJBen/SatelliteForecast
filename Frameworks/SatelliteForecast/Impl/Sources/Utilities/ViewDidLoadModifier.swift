//
//  ViewDidLoadModifier.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 3/7/22.
//

import SwiftUI

/// A view modifier that enables `-viewDidLoad` like semantics in SwiftUI.
/// Solution adopted from https://stackoverflow.com/a/64495887/1085698
struct ViewDidLoadModifier: ViewModifier {
    @State private var didLoad = false
    private let action: (() -> Void)?

    init(perform action: (() -> Void)? = nil) {
        self.action = action
    }

    func body(content: Content) -> some View {
        content.onAppear {
            if didLoad == false {
                didLoad = true
                action?()
            }
        }
    }
}

extension View {
    /// Perform the action block when the view is loaded for the first time.
    /// - Parameter action: The action block to perform.
    /// - Returns: A view with the modifier added.
    public func onLoad(perform action: (() -> Void)? = nil) -> some View {
        modifier(ViewDidLoadModifier(perform: action))
    }
}
