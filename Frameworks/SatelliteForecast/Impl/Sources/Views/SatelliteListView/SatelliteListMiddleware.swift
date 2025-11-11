//
//  SatelliteListMiddleware.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 11/23/22.
//

import Foundation
import BTree
import Combine
@preconcurrency import CombineRex
import SatelliteForecast

private let satelliteTextSearchQueue = DispatchQueue(label: "satellite_text_search")

extension EffectMiddleware where InputActionType == SatelliteListViewAction, OutputActionType == SatelliteListViewOutput, StateType == SatelliteListViewState, Dependencies == Void {
    public static var satelliteList: EffectMiddleware<SatelliteListViewAction, SatelliteListViewOutput, SatelliteListViewState, Void> {
        EffectMiddleware.onAction { action, _, getState in
            switch action {
            case .searchSatellites(let searchText, let category):
                return .promise(token: "search_\(searchText)") { context, sink in
                    satelliteTextSearchQueue.async {
                        var content: Map<UInt, SatelliteInfo>?
                        if searchText.isEmpty {
                            content = nil
                        } else {
                            content = getState().satelliteInfo[category]?.content
                            var filteredContent = Map<UInt, SatelliteInfo>()
                            content?.forEach { (noradIndex, value) in
                                if value.fitsSearchText(searchText) {
                                    filteredContent[noradIndex] = value
                                }
                            }
                            content = filteredContent
                        }

                        sink(
                            .filteredSatellites(
                                content,
                                searchText: searchText,
                                category: category
                            )
                        )
                    }
                }
            case .loadSatellite(_), .retryLoadingSatelliteList(category: _), .selectSatellite(_, category: _), .reloadSatellites:
                return .doNothing
            }
        }
    }
}

private let yearFormatter: DateFormatter = {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy"
    return dateFormatter
}()

fileprivate extension SatelliteInfo {
    func fitsSearchText(_ searchText: String) -> Bool {
        guard !searchText.isEmpty else {
            return true
        }

        let searchText = searchText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        if String(noradIndex).contains(searchText) {
            return true
        } else if elements.commonName.lowercased().contains(searchText) {
            return true
        } else if satCat?.cosparID.lowercased().contains(searchText) ?? false {
            return true
        } else if satCat?.launchSite.code.lowercased().contains(searchText) ?? false {
            return true
        } else if let date = satCat?.launchDate, yearFormatter.string(from: date) == searchText {
            return true
        } else if let ucsSat = ucsSat {
            return ucsSat.name.lowercased().contains(searchText)
            || ucsSat.countryOfOperatorOrOwner.lowercased().contains(searchText)
        }

        return false
    }
}
