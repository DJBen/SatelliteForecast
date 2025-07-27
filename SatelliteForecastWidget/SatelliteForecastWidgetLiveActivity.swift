//
//  SatelliteForecastWidgetLiveActivity.swift
//  SatelliteForecastWidget
//
//  Created by Sihao Lu on 7/26/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

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
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

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
            .keylineTint(Color.red)
        }
    }
}

extension SatelliteForecastWidgetAttributes {
    fileprivate static var preview: SatelliteForecastWidgetAttributes {
        SatelliteForecastWidgetAttributes(name: "World")
    }
}

extension SatelliteForecastWidgetAttributes.ContentState {
    fileprivate static var smiley: SatelliteForecastWidgetAttributes.ContentState {
        SatelliteForecastWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: SatelliteForecastWidgetAttributes.ContentState {
         SatelliteForecastWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: SatelliteForecastWidgetAttributes.preview) {
   SatelliteForecastWidgetLiveActivity()
} contentStates: {
    SatelliteForecastWidgetAttributes.ContentState.smiley
    SatelliteForecastWidgetAttributes.ContentState.starEyes
}
