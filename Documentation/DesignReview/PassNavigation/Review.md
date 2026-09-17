# Invisible-pass navigation review

The supplied iOS 27 recording shows a whole-page navigation transition exposing black content on the first left swipe. The chart itself remains intact. Invisible passes used `navigationDestination(item:)` driven by a local selection, while visible passes used the owning `NavigationPath` and a value destination.

The grid now appends `AllPassViewNavigation` to the owning navigation path. Both the forecast and satellite-catalog stacks supply their existing bindings. The separate selection and item-driven destination are removed. Cards remain independent plain buttons: an attempted pair of value links in the same List row selected the wrong card during testing, so that approach was discarded.

## Verification

Dark-mode interactive fixture on iPhone 17 Pro Max simulator, iOS 26.5:

- Left card opens the June 2, 2021 06:20 rise / 06:26 culmination pass.
- Right card opens the distinct 07:58 rise / 08:03 culmination pass.
- First left swipe and subsequent left swipes preserve the detail page.
- Right-edge-direction back gesture from the left screen edge returns to the list.
- Cancelling a short back gesture leaves the detail usable; a later Back-button tap restores the list.
- The hosted test confirms the navigation path is empty after returning to the list.
- Simulator recording was reviewed frame by frame around the first swipe. Retained screenshots show each card's detail after the swipe.

The 31 ForecastTests also pass, including pass presentation state, timeline, and navigation-related coverage. The device Debug build succeeded and was installed and launched on Sihao’s iPhone.

The exact iOS 27 flash did not reproduce on the installed iOS 26.5 simulator. The route inconsistency is removed, but final confirmation of that OS-specific transition requires retrying on the connected iPhone. The updated device build is installed for that check.

## Repeat the interactive check

Create `/tmp/satellite-pass-navigation-review`, then run:

```sh
xcodebuildmcp simulator test --scheme SatelliteForecastApp --project-path SatelliteForecast.xcodeproj --simulator-id 5D6FFD0C-6B24-4F95-8E94-B7F3EBD22FDB --extra-args="-only-testing:SatelliteForecastTests/ScreenSnapshotTests/testInteractivePassNavigation"
```

The test hosts an offline fixture with four invisible passes and no visible passes. Wait for `/tmp/satellite-pass-navigation-review-ready` to be updated. Tap each first-row card separately, swipe left, and return. Finish on the list and remove the marker to complete the test. Without the marker, the interactive test is skipped.
