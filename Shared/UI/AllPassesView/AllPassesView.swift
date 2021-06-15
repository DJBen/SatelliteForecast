//
//  AllPassesView.swift
//  SatelliteForcast (iOS)
//
//  Created by Ben Lu on 6/14/21.
//

import CombineRextensions
import SatelliteForcastCore
import SwiftUI

enum AllPassesViewAction {
    
}

struct AllPassesViewState: Equatable {
    var passes: [PassInformation]
}

struct AllPassesView: View {
    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
    }
}

struct AllPassesView_Previews: PreviewProvider {
    static var previews: some View {
        AllPassesView()
    }
}
