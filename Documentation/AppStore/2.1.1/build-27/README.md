# 2.1.1 build 27 — internal TestFlight

Published **2.1.1 (27)** to the **First Light internal TestFlight** group on
October 4, 2026. Apple processing is `VALID`, internal distribution is
`IN_BETA_TESTING`, and external distribution is `NOT_APPLICABLE`.
Build ID: `6a516f46-91bd-41f4-b171-f2b141e16914`.
The final build, distribution and verified English test notes are saved here.

## Changes

- Alarms is the fourth tab, with a bell, between Satellites and Settings.
- Notification permission: explicit first-time OS prompt, recovery link for denied
  access, and no card when authorized. Returning from iOS Settings refreshes
  authorization and activates the existing authorized station push registration.
- Grouped local alarms show a prominent alert time, date/weekday column, station,
  relative timing, sound and compact pass context. Empty state and Add lead to
  Choose a pass. Saved rows share the native date/time picker with pass details.
- Edits replace the saved entry by pass ID after OS acceptance, retain attachments
  and the original observer/pass, and persist the updated time across reloads.
- Local PASS notifications request default sound and allow it in foreground.

## Visual and interaction evidence

Behavior suite: 165 passed, 3 optional fixtures skipped, zero failed. The two
opt-in visual and interaction tests also passed.

`alarms-review/` contains dark reviews at 440×956, eight locales, 375-point width,
and accessibility text size 3 (including scrolled views). Historical June 2, 2021
alarm fixture dates are illustrative; they are not new forecast/store moments.
The localized views explicitly use UTC; live simulator captures use its local
time zone. No store screenshots or moment inputs were changed.

Live iPhone 17 Pro Max captures confirm the fourth-tab placement, visible page
header, extracted Settings screen, Edit/Done controls, shared editor and delete
state. The interactive fixture asserts cancel preserves the original alarm and
delete removes it from shared state and persistence.

The OS prompt and denied recovery card were exercised on a fresh iPhone 17 Pro
Max simulator during the preceding review (build-26/alarms-review). Fixture
permission states also cover authorized, provisional, ephemeral and unknown.
The supported UIKit notification-settings URL opened the Settings root on the
iOS 27 simulator during this review; it did not resolve the app-specific
notification page. Verify the destination and return flow on a physical
TestFlight device. This uses Apple's
[public notification-settings API](https://developer.apple.com/documentation/uikit/uiapplication/opennotificationsettingsurlstring).
Physical push delivery and audible alarm delivery also remain device TestFlight checks.

## Release scope

Internal-only export (`testFlightInternalTestingOnly=true`), First Light automatic
internal group. Build 26 was expired after the full-app title issue was discovered
and is superseded by this build. No external beta review or App Store submission
is part of this release. Existing public App Store version is 2.1.0.

Archives and IPA remain in /tmp; compiler, test, export and publish logs are saved
in this directory. Unrelated pre-existing workspace changes were preserved.
