# Active pass experience review

Reviewed `main` at `6a31b017ac9f975e2fb24e2ab607ef9538683f3e` (September 27, 2026). Fetch completed; main already matched origin/main. No product implementation changes are proposed as part of these captures.

[Open screenshot gallery](gallery.html) · [Widget matrix](widget-matrix.jpg) · [Pinned moments](moments.json)

## Result

The live experience is recognizable, but it does not yet provide consistent observation guidance across all four surfaces. Home gives the clearest live signal. Detail has useful real-time information but weak live hierarchy. Planetarium helps find an off-screen station. Widgets announce an active pass but continue showing a static overview.

The most important correctness issue is that **“passing” and “visible now” have different boundaries across surfaces**.

| Surface | Verified behavior | Recommended change |
| --- | --- | --- |
| Home | Coral “Passing now,” station name, live elevation marker, and “Live position.” The page still says “Next observation.” Total visible duration and peak elevation remain the summary. The hero is tappable, but the live state has no labeled observing button. | Change the active heading to “Observe now.” Add “Look [direction] · [current elevation]° up” and “Visible for [remaining time].” Keep an explicit “Find in sky” action during the pass, leading into planetarium Now mode. |
| Detail | A live dot and rotated elevation/time label appear on the sky chart. The title is the pass date; the subtitle describes rise/set directions. It does not prominently name the station or state that it is passing. The event table remains a schedule. The eye action is icon-only. | Lead with “ISS / Tiangong · Visible now,” current direction/elevation and remaining visibility. Highlight the next event and dim completed events. Make “Find in sky” primary and label the Live Activity action “Follow on Lock Screen.” |
| Planetarium | Opens in Now mode during a geometric pass. The off-screen pointer has a clear “[station] passing now” badge and supports recentering. The centered capture loses the coral passing badge; status is coupled to that pointer rather than a persistent header. | Keep a compact live status and remaining time visible whether the station is in or out of frame. Label the pointer “Find ISS/Tiangong” or “Turn [direction].” Distinguish “Above horizon · in Earth’s shadow” from “Visible now.” |
| Widgets | All four layouts show coral “Passing.” The small chart’s peak dot and large chart’s event markers are static; there is no current-position marker or remaining time. The medium row shows the full route and duration. No widgetURL or per-row Link supplies a pass-specific destination. | Use consistent visible-state boundaries, a system-updating remaining-time display where supported, and a pass/location-specific deep link. Use “Open live view” as the action cue. Preserve the overview chart, but clearly distinguish its peak/event markers from a live position. |

## P1 — Visibility disagreement after shadow entry

Home uses `ObservationOpportunity.start/end`, based on illuminated intervals. Planetarium's `isPassing` uses rise/set. Widget data stores geometric rise/set, `next` retains the pass until set, and timeline entries include rise/set rather than shadow transitions.

Reproduced with both pinned stations at the same observer `(37.486743, -122.226560)`, America/Los_Angeles:

| Station | Visible portion ends | Horizon set | Misleading interval |
| --- | --- | --- | --- |
| ISS, Sep 9 local | 8:43:39 PM | 8:46:12 PM | About 2m 33s |
| Tiangong, Sep 10 local | 8:33:51 PM | 8:38:00 PM | About 4m 9s |

At the midpoint of each interval, home has moved to the next observation, planetarium still displays “[station] passing now,” and every widget still says “Passing.” This can send someone outside to look for a station that has already become unobservable in shadow.

Evidence: [ISS shadow planetarium](iss-shadow-planetarium-offscreen.png), [Tiangong shadow planetarium](tiangong-shadow-planetarium-offscreen.png), [ISS shadow widget](iss-shadow-widget-large.png), [Tiangong shadow widget](tiangong-shadow-widget-large.png).

Proposal: define a shared observation state with explicit visible intervals, current illumination, and next transition. Keep geometric pass progress separately. Publish visibility transitions to WidgetKit. Use “Visible now,” “In Earth’s shadow,” and “Observation ended” consistently. Retain a brief ended state so someone already following the pass understands why it vanished.

Related code: `ObservationOpportunity.swift:10`, `PlanetariumView.swift:28`, `ForecastModel.swift:136`, `WidgetForecast.swift:180–191`.

## P2 — Duration and peak can look like current guidance

At the active moment, ISS home says “Visible for 9 min” while its widget says “11 min.” Tiangong says 7 min versus 11 min. Home summarizes total illuminated time; widgets summarize total horizon-to-horizon duration. Neither is the remaining observing time. The widget's 56°/87° badge is the maximum elevation, not the station's current elevation.

Proposal: during a visible pass, prefer “Visible for 3m 55s more,” then current bearing/elevation in the app. Mark peak values explicitly as “Peak.” Avoid implying that a widget's cached sky chart is continuously live.

Related code: `ObservationHomeView.swift:422`, `StationWidgetView.swift:132`, `StationWidgetView.swift:290`.

## P2 — Preserve an obvious next action

Home replaces its pre-pass action area with the small “Live position” label. Tapping the card works by source inspection, but that action is not visually explicit. Detail then loses the station name and passing status in its title. Planetarium is available, but the user has to infer that it is the tool for finding the station.

Proposal flow: **Visible now → Find in sky → Planetarium in Now mode**, with the selected station, observer and pass carried through. Keep “Sky chart” available as an alternate view. Make the eye button's Lock Screen purpose explicit instead of relying on icon recognition.

Related code: `ObservationHomeView.swift:195`, `ObservationHomeView.swift:430`, `PassView.swift:124`, `PassView.swift:202`.

## Additional observations

- In the small two-station widget with ISS active and no Tiangong pass, the secondary message truncates to “No visible…”. Use a shorter secondary status that retains its meaning.
- The Tiangong near-overhead home arc occupies much less of the available preview width than the ISS arc. This makes the live target less prominent. Review a minimum useful chart scale without changing the underlying projection's meaning.
- Compass/device-follow controls need a physical-device outdoor check. The simulator cannot establish whether actual pointing guidance feels natural.

## Runtime finding requiring reproduction

The first Debug capture run crashed after showing the active ISS detail chart. The crashing thread was `com.apple.SwiftUI.AsyncRenderer`; the stack reaches `_dispatch_assert_queue_fail` through the `VibrancyEffectStyleKey` EnvironmentKey default getter. That key is declared `@MainActor`, and the live chart label uses the vibrancy modifier.

Evidence: [crash report](live-detail-crash.ips), [failed-run log](initial-crash.log). This occurred in a hosted snapshot review while switching views; it is not evidence that the public release crashes in a normal navigation flow. Reproduce through normal home → live detail navigation before assigning release severity. Do not treat the capture failure as a passing runtime test.

## Method and limits

- Actual native SwiftUI/Metal app views rendered on the iPhone 17 Pro Max simulator, iOS 27, dark mode. Native app PNGs are 1320 × 2868.
- Pinned September 2026 TLE files from `SatelliteForecastTests/Fixtures/AppStore`; real propagated passes, not invented positions. `moments.json` records selected times.
- Fixtures supply a controlled clock. The detail live marker additionally needs the existing chart time-offset injection because its timer reads real time independently of the context clock. This is capture setup, not a product change.
- Widget PNGs are actual shared `StationWidgetView` content rendered at small 170×170, medium 364×170, large 364×382 points at 3×. They are **not installed Home Screen screenshots**; WidgetKit reload scheduling and tap navigation were inspected in source, not exercised on SpringBoard.
- Each station scenario supplies that station's passes. The other station's “No visible pass” state is intentional fixture data, not a claim about the real sky.
- The shadow home capture advances to a different pass; its preview spinner reflects the fixture retaining the previous preloaded preview with network loading disabled. It is not reported as a product loading bug.
- English, standard text size. Localization, accessibility text sizes, physical-device motion, real-time network refresh, and Live Activity lifecycle are outside this review.
- Source inspection and controlled state captures verify presentation; they are not a complete end-to-end tapping or transition test.

## Suggested implementation order

1. Unify visible-state and shadow-transition semantics across app and widgets.
2. Add the active header, remaining visibility and primary observing action to home/detail.
3. Keep persistent live guidance in planetarium and add pass-specific widget navigation.
4. Investigate the Debug live-detail crash, then check the complete flow on a physical phone.

Acceptance should cover both stations before visible start, rising, near peak, fading into shadow, and after observation ends. Verify the same station, location and visible state on every surface, plus a clear explanation when a visible observation ends before geometric set.

The reusable review method and host-side capture runner are preserved as text files alongside this report. To reproduce, temporarily insert the method into `ScreenSnapshotTests`, run the corresponding runner from the repository root, and restore the test file afterward. The runner restores the test plan in `finally`. Use a new output directory for future review evidence.

Validation: the main state-capture test passed, and both supplementary centered-planetarium/live-detail capture runs passed (three successful test executions total). The earlier capture crash remains documented; later success does not establish its cause or resolution. Temporary test-source and test-plan edits were restored. Only this evidence directory remains as a repository addition.

Raw diagnostic logs and the original crash report are retained locally and excluded from source control; their links above refer to local evidence.
