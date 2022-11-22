//
//  DetailedPassViewBackgroundAnnotationView.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 11/22/22.
//

import SwiftUI
import SatelliteKit

public struct DetailedPassViewBackgroundAnnotationView: View {
    let raDecToPoint: (RADec) -> CGPoint

    public init(
        raDecToPoint: @escaping (RADec) -> CGPoint
    ) {
        self.raDecToPoint = raDecToPoint
    }

    public var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
    }
}
