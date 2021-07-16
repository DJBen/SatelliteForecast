//
//  LazyView.swift
//  SatelliteForcast
//
//  Created by Ben Lu on 7/15/21.
//

import SwiftUI

/// A lazy view that only builds the child content upon being rendered.
/// This is especially useful in NavigationLink's destination.
/// - seealso: https://stackoverflow.com/q/57594159/1085698
struct LazyView<Content: View>: View {
    let build: () -> Content

    init(_ build: @autoclosure @escaping () -> Content) {
        self.build = build
    }
    var body: Content {
        build()
    }
}
