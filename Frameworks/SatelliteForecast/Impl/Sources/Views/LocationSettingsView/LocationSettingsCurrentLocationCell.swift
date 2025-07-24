//
//  LocationSettingsCurrentLocationCell.swift
//  LocationSettingsCurrentLocationCell
//
//  Created by Ben Lu on 8/6/21.
//

import SwiftUI
import CoreLocation
import Contacts

public struct LocationSettingsCurrentLocationCell: View {
    var currentLocation: CLLocation?
    var currentLocationPlacemark: CLPlacemark?
    var isSelected: Bool = false

    public init(
        currentLocation: CLLocation?,
        currentLocationPlacemark: CLPlacemark?,
        isSelected: Bool = false
    ) {
        self.currentLocation = currentLocation
        self.currentLocationPlacemark = currentLocationPlacemark
        self.isSelected = isSelected
    }

    static let addressFormatter: CNPostalAddressFormatter = {
        let formatter = CNPostalAddressFormatter()
        formatter.style = .mailingAddress
        return formatter
    }()

    public var body: some View {
        HStack {
            if let _ = currentLocation {
                Image(systemName: "location")
            } else {
                Image(systemName: "location.slash")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.red, Color(uiColor: .label))
            }

            VStack(alignment: .leading, spacing: 2) {
                if let currentLocation = currentLocation {
                    Text("Current location", bundle: .module)

                    if let formattedPlacemark = currentLocationPlacemark?.formattedString {
                        Text(formattedPlacemark)
                            .font(.system(.caption))
                            .foregroundColor(Color.secondary)
                    }

                    Text(currentLocation.coordinate.formattedString)
                        .font(.system(.caption2))
                        .foregroundColor(Color.secondary)
                        .tint(nil)
                } else {
                    Text("Current location not available", bundle: .module)

                    Text("Open location settings", bundle: .module)
                        .font(.system(.caption))
                        .foregroundColor(Color.secondary)
                        .tint(nil)
                }
            }

            if currentLocation == nil {
                Spacer()
                Image(systemName: "rectangle.portrait.and.arrow.right")
            } else if isSelected {
                Spacer()
                Image(systemName: "checkmark")
            }
        }
    }
}

#if DEBUG
struct LocationSettingsCurrentLocationCell_Previews: PreviewProvider {
    static var previews: some View {
        LocationSettingsCurrentLocationCell(
            currentLocation: nil,
            currentLocationPlacemark: nil
        )
            .previewLayout(.fixed(width: 350, height: 50))

        LocationSettingsCurrentLocationCell(
            currentLocation: CLLocation(latitude: 32.123, longitude: 45.678),
            currentLocationPlacemark: nil
        )
        .previewLayout(.fixed(width: 350, height: 50))
    }
}
#endif
