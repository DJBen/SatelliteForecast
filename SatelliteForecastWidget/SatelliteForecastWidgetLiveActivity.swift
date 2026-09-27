//
//  SatelliteForecastWidgetLiveActivity.swift
//  SatelliteForecastWidget
//
//  Created by Sihao Lu on 7/26/25.
//

import ActivityKit
import WidgetKit
import SwiftUI
import SatelliteWidgetSupport

struct SatelliteForecastWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct SatelliteForecastWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SatelliteForecastWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .foregroundStyle(MoonstonePalette.text)
            .activityBackgroundTint(MoonstonePalette.background)
            .activitySystemActionForegroundColor(MoonstonePalette.accent)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(MoonstonePalette.accent)
        }
    }
}
