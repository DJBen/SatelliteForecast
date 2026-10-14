# iPad UX review and gap plan

Reviewed October 12, 2026. Source: `ed03b8802a297f7682d6d34ef0d7526696ce3d66` plus the review-only capture harness. App version 2.1.1 (29). All captures use dark mode.

The astronomy visuals are a good foundation for iPad. The main work is native support and adaptive composition: keep related information together, bound reading widths, and use the extra space for useful detail. Enabling the iPad device family alone would expose several oversized phone layouts.

Generated screenshots, galleries, capture metadata and logs are kept locally and are not stored in Git. Reproduce the evidence with the capture scripts below.

## What was reviewed

- Two actual iPad Pro 13-inch (M5), iOS Simulator 27.0 screenshots of the current iPhone-only build: welcome and the live Home screen. The observer was simulated in Redwood City, not taken from the user's device.
- 42 native-view captures hosted on that iPad simulator using a separate Debug build with `TARGETED_DEVICE_FAMILY=1,2`. App and widget shipping settings were left untouched.
- Controlled canvases: Pro portrait 1032 × 1376 pt, Pro landscape 1376 × 1032 pt, mini portrait 744 × 1133 pt, and a narrow 500 × 900 pt window. The mini and narrow cases are layout canvases, not separate device runs or actual window-resizing sessions.
- Fourteen scenarios in each Pro orientation: Home, pass chart, station passes, Satellites, planetarium, both onboarding pages, satellite search content, Sky now content, Settings content, location content, alarm editor, empty alarms, and saved alarms. Six scenarios on each smaller canvas, plus Home and saved alarms at Accessibility 3 in the narrow canvas.
- Home, pass chart, station pass list and Satellites include the real root tab bar. Secondary screens are hosted feature content, so their screenshots do not establish root-tab presentation behavior.
- The catalogued California moment, ISS/Tiangong TLEs, observer, and America/Los_Angeles time zone are reused. Fixture weather is illustrative. The gallery labels diagnostic content separately from the actual compatibility screenshots.

The capture test checks the iPad idiom and requested view dimensions. Its passing result establishes that the evidence was generated; it is not an end-to-end UX or accessibility certification. Physical iPad input, permissions, keyboard behavior, popovers, real resizing/rotation continuity, and GPU performance remain validation work. Simulator input automation was incompatible with the installed Xcode's framework layout; captures use native hosting rather than claiming that unverified taps completed flows.

## Findings

| Priority | Gap and user impact | Evidence | Proposed change | Acceptance |
| --- | --- | --- | --- | --- |
| P0 | The app and widget target iPhone only. The current app opens in a narrow compatibility window on iPad. | Actual Home (local capture); app target Debug/Release device family is `1`, as are the widget targets. | Prepare universal app and widget targets in an isolated implementation branch. Ship after the adaptive layouts and actual iPad validation are ready. | Built app and widget both include device family `2`; clean install runs as an iPad app. Verify widget gallery and home-screen installation on iPad. |
| P1 | The pass chart uses almost all available height. In landscape, chart controls and event times are entirely below the first viewport. | Landscape chart (local capture), portrait chart (local capture). | Place a bounded chart beside a pass summary, event timeline and actions when the window is wide. Keep a stacked layout at narrow widths. | On Pro landscape, chart, rise/peak/end times, Compass, Chart, Planetarium and alarm access are visible together at default text size. At large text, every action remains reachable by scrolling. |
| P1 | Home stretches a single card across the display while its sky preview remains small. Row names and times are separated by excessive space. | Landscape Home (local capture), portrait Home (local capture). | Use a bounded content region with observation card and Coming up side by side on wide windows. Give the sky preview an intentional aspect ratio. Keep location/weather together above them. | At wide widths, the next observation and several upcoming passes are legible at a glance. The preview occupies useful space, and no action stretches across the entire screen. |
| P1 | Pass and satellite browsing remains one wide list and a separate pushed destination; the iPad does not help compare a selected pass with its neighbors. | Station list (local capture), satellite search content (local capture). | Use a list/detail arrangement for station passes and satellite search at wide widths. Preserve existing stack navigation in compact windows. Keep selection in feature state so changing width does not reset it. | Select another pass without losing the list. Collapse and expand while keeping the selected pass, search, scroll position and Back behavior. Deep links select the correct detail in either layout. |
| P1 | Satellite cards stay vertically stacked with fixed media heights, producing panoramic crops and long scrolls. | Satellites landscape (local capture). | Put ISS and Tiangong cards in a two-column station section, followed by an adaptive category grid. Preserve image aspect ratios and readable text. | Both station cards and entry points to categories are easily discoverable. Long localized labels wrap without cropping or requiring tiny text. |
| P1 | The alarm editor and Settings/location content use the full width for a small amount of content. Pass detail presents the alarm editor with `fullScreenCover`. | Alarm editor (local capture), Settings (local capture), location (local capture); `PassView.swift` presentation code. | Constrain forms and rows to a comfortable width; use a focused sheet for alarm editing on iPad. Keep Cancel and Save close to the task. Anchor local menus/popovers to the initiating control. | The complete alarm task fits a focused panel; keyboard appearance does not obscure search results or confirmation. Native dismiss/Cancel behavior and unsaved changes remain predictable. |
| P2 | Onboarding retains a bottom copy block and very wide button; the demo and copy do not form a tablet composition. | Welcome landscape (local capture), predictions landscape (local capture). | Cap text/action widths. Compose media and copy side by side where it helps, with a stacked fallback. | Copy is comfortable to read in both orientations and at large text; Continue/Get started are immediately discoverable. Evaluate live video separately from the frozen screenshot fixture. |
| P2 | Tablet input and presentation behavior lack evidence. There are no explicit app keyboard shortcuts or adaptive split-navigation declarations in the reviewed view source. | Source inspection; narrow large-text Home (local capture), large-text alarms (local capture). | Add useful keyboard navigation/search/dismiss shortcuts and review pointer targets, focus order, VoiceOver and mounted-device sky interaction. | Complete search → pass → alarm with keyboard; dismiss overlays with Escape; all controls have clear labels and at least 44 pt effective touch targets. Live resizing preserves state. |

P0 is a release blocker for a native iPad offering. P1 items materially improve the main observation workflow. P2 items complete platform fit and validation. Multiple independent app windows are a separate product choice; the existing single-scene declaration alone is not a usability defect.

## What to retain

- The dark Moonstone surfaces, restrained accent colors and readable pass information.
- The native top tab bar on regular-width iPad layouts. It already adapts on the mini-sized canvas with overflow; make sure Settings remains discoverable before deciding whether sidebar adaptation adds value.
- The immersive planetarium. It uses the display far more effectively than the stretched lists and forms. Keep its sky canvas dominant, with compact playback and selection controls.
- Alarm row reflow at Accessibility 3. It prioritizes alert time and satellite without shrinking text. Scrolling at larger text sizes is expected, not a failure.
- Existing compact navigation and the distinction between automatic station alerts and local per-pass alarms.

## Implementation sequence

### 1. Establish native iPad support and shared layout rules

Prepare universal app/widget builds and test clean installation. Define width-driven layout rules: compact windows keep stacks; medium windows use bounded single-column content or grids; sufficiently wide windows gain list/detail and two-column compositions. Start by exploring 700–900 pt as the transition range, then choose breakpoints from actual content fit rather than device names. Test 500 pt windows and accessibility text before finalizing them.

Constrain Settings/location/alarm content to roughly 560–680 pt, and bound the main Home region to roughly 1100–1200 pt. These are starting design values, not fixed requirements. Reuse semantic colors, type and card spacing. Keep observation and navigation state independent of the chosen layout.

Primary ownership: `SatelliteForecast.xcodeproj/project.pbxproj`, `SatelliteForecastApp/Info.plist`, `RootView.swift`, and shared view utilities. Verify the widget target independently rather than assuming the application override makes widget delivery complete.

### 2. Make the observation workflow use the display

Implement pass chart + event/action detail first, then Home observation + Coming up. Size the chart using available space after reserving actions and timeline, rather than `min(width, height)` alone. Follow with station pass list/detail and satellite category grids. Avoid rebuilding expensive renderers or resetting camera/selection when a window crosses a breakpoint.

Primary ownership: `PassView.swift`, `ObservationHomeView.swift`, `ObservationSkyPreview.swift`, `ObservationPassRow.swift`, `AllPassesView.swift`, `SatelliteCategoryView.swift`, `SatelliteOverviewCell.swift`, and `SatelliteCategoryCell.swift`.

### 3. Focus secondary tasks and tablet input

Make the alarm editor a focused iPad sheet, bound forms, and verify search/confirmation with a real keyboard. Refine onboarding. Evaluate a sidebar-adaptable tab experience if it improves discovery while keeping the five stable feature destinations.

Add a small set of useful shortcuts: tab selection, search focus, Back/dismiss, and clearly documented sky controls. Verify that dragging the sky is comfortable with touch and trackpad and that device-follow behavior works when the iPad is on a stand. Adapt phone-shaped orientation guidance if it is confusing on a tablet.

Primary ownership: `PassAlarmSettingsModalView.swift`, `AlarmSettingsView.swift`, `SettingsOverviewView.swift`, `LocationSettingsView.swift`, `OnboardingView.swift`, `RealtimeSkyView.swift`, and planetarium input/guidance views.

### 4. Validate on actual windows and hardware before delivery

Use iPad Pro 13-inch, an 11-inch iPad, and iPad mini in portrait/landscape; include narrow and short windows. Exercise location selection, offline/loading/retry states, notification permission denial, create/edit/delete alarm, deep links, and satellite selection. Rotate and resize during each task. Keep selected pass, list position, draft alarm, filters and sky camera stable.

Run VoiceOver and large text checks, long localized labels, hardware keyboard/trackpad use, and Metal frame pacing/memory checks. Verify background/reactivation and sensor-unavailable behavior. Hosted image canvases remain useful regression evidence, but do not substitute them for these live checks.

For implementation changes, follow AGENTS.md: rebuild/rerun after each app change, review dark mode, and also install/launch the latest Debug app on the currently discovered “Sihao’s iPhone.” Preserve the stable `AppAnalytics` screen names and success boundaries documented in `Documentation/Analytics.md`; layout changes do not justify logging coordinates, queries, identifiers or frame data.

## Completion criteria

- Native iPad app and widget installation confirmed.
- Main observation task works in one clear view on a wide iPad; every action remains accessible in a compact window.
- Focused alarm/location tasks work with touch, keyboard and accessibility settings.
- Rotation/resizing and deep links retain task context.
- iPhone layout and existing alarm/analytics semantics remain correct.
- Updated, visually reviewed dark screenshots represent actual supported iPad windows as well as deterministic fixtures.

No application implementation fixes are included in this review. The added code is an opt-in screenshot harness and gallery tooling.

## Reproduce the layout evidence

```sh
python3 scripts/capture-ipad-ux-review.py \
  --output Documentation/UX/iPad/YYYY-MM-DD \
  --simulator <iPad-simulator-UUID> \
  --derived-data /tmp/SatelliteForecast-iPad-review \
  --packages <existing-SourcePackages-directory>
python3 scripts/build-ipad-ux-gallery.py --output Documentation/UX/iPad/YYYY-MM-DD
```

The capture script temporarily supplies review environment variables through the test plan and restores the original plan in `finally`. It records to a separate directory and does not replace phone baselines. Use `--canvases` and `--screens` for targeted recaptures. The actual compatibility screenshots are separate live simulator captures and must be supplied when rebuilding this gallery elsewhere.
