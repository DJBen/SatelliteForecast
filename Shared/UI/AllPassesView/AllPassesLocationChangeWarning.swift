//
//  AllPassesLocationChangeWarning.swift
//  AllPassesLocationChangeWarning
//
//  Created by Ben Lu on 8/16/21.
//

import MapKit
import SwiftUI
import SatelliteKit

struct AllPassesLocationChangeWarningState: Equatable {
    var observer: CLLocationCoordinate2D
    var observerDescription: String?
    var oldObserver: CLLocationCoordinate2D
}

struct AllPassesLocationChangeWarning: View {
    var state: AllPassesLocationChangeWarningState
    var onRecalculatePasses: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            Text(localizedString)
                .font(.caption)

            Button("Recalculate using new location", action: onRecalculatePasses)
                .font(.footnote.bold())
        }
        .padding(16)
        .background(.yellow)
        .frame(maxWidth: .infinity)
    }
    
    private var localizedString: String {
        let formatString = NSLocalizedString(
            "AllPassesLocationChangeWarning.text",
            tableName: nil,
            bundle: .main,
            value: "The new location %1$@ is %2$@ away from the location that was used to calculate the passes. The results may no longer be accurate.",
            comment: "The text for a warning label upon significant deviation of the location used to calculate passes from the current location."
        )
        
        let distance = MKMapPoint(state.observer).distance(to: MKMapPoint(state.oldObserver))
        let formatter = MKDistanceFormatter()
        formatter.unitStyle = .full
        let distanceString = formatter.string(fromDistance: distance)
        
        let observerString: String = {
            if let observerDescription = state.observerDescription {
                return observerDescription
            } else {
                return state.observer.formattedString
            }
        }()
        
        return String(format: formatString, observerString, distanceString)
    }
}

struct AllPassesLocationChangeWarning_Previews: PreviewProvider {
    static var previews: some View {
        AllPassesLocationChangeWarning(
            state: AllPassesLocationChangeWarningState(
                observer: CLLocationCoordinate2D(latitude: 23, longitude: 110),
                observerDescription: nil,
                oldObserver: CLLocationCoordinate2D(latitude: 23.14, longitude: 111.0)
            ),
            onRecalculatePasses: {
                
            }
        )
        .previewLayout(.fixed(width: 250, height: 50))
    }
}
