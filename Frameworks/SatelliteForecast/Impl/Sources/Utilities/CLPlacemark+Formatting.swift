//
//  CLPlacemark+Formatting.swift
//  CLPlacemark+Formatting
//
//  Created by Ben Lu on 8/7/21.
//

import Foundation
import Contacts
import CoreLocation

private let addressFormatter: CNPostalAddressFormatter = {
    let formatter = CNPostalAddressFormatter()
    formatter.style = .mailingAddress
    return formatter
}()

extension CLPlacemark {
    public var formattedString: String? {
        guard let postalAddress = postalAddress else { return nil }
        let formatterString = addressFormatter.string(from: postalAddress)
        return formatterString.replacingOccurrences(of: "\n", with: ", ")
    }
}
