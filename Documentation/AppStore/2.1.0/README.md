# iOS 2.1.0

Build **24** is prepared for the App Store with automatic release (**AFTER_APPROVAL**),
new weather home screenshots in all eight locales, and zero API validation errors or
warnings. It is attached to the **PREPARE_FOR_SUBMISSION** draft and available to
internal First Light testers. **Not submitted for App Review yet**: the public privacy
label still says Data Not Collected, and an authenticated website session is needed
to publish the prepared correction. See [build 24 preparation and remaining access](build-24/README.md).

## Initial internal-only release

Build **23** (`16d5fb04-39a2-4d78-9af6-2293980fa283`) is VALID and
**IN_BETA_TESTING** for internal **First Light**. The group automatically receives
all builds. Export set `testFlightInternalTestingOnly=true`; Apple reports external
state **NOT_APPLICABLE**. What to Test notes were read back and match the saved
text, ignoring the final newline trimmed by the CLI.

The initial build 23 request created no App Store draft, review submission or public
release. The later build 24 preparation above creates the draft; public version 2.0.1
and its live store screenshots remain unchanged pending review.

## Included changes

- Home weather appears on one line beside the location: icon, locale-formatted
  temperature, and condition where space permits. A compact icon/temperature
  fallback accommodates long localized location labels.
- ClearSkyChart Firebase weather reuses shared H3 area/time-window caches; small
  movement within the same fresh area avoids another provider fetch.
- Automatic ISS/Tiangong pushes place station/time in the title,
  direction/duration/elevation in the subtitle, and weather guidance in the body,
  in all eight app languages. Fresh high-confidence rain throughout the visible
  pass suppresses the automatic reminder. Manual local alarms are unchanged.
- App and widget both use 2.1.0 (23). Archived source release commit: `5677a6c`.
  Weather notifications were already merged at `b6919ee4` in SatelliteForecast
  and `b9df31e` in ClearSkyChart. `notify`, `notify_prominent`, and private
  `notificationWeather` were deployed and confirmed ACTIVE.
- Privacy and support copy were corrected and deployed to describe approximate
  home-weather requests, anonymous weather sessions, and rain suppression.

## Validation

- iPhone 17 Pro Max / iOS 27 behavior suite: 157 total, **154 passed**, 0 failed,
  3 optional review fixtures skipped. Localization audit passed across 8 languages.
- Weather notification regressions passed 80 Python and 27 TypeScript tests. Live
  runtime-identity weather access and nearby-location cache reuse are recorded in
  the weather notification design-review evidence.
- Archive and export succeeded. App/widget versions, code signatures, App Group,
  production APNs and disabled debugging entitlement were verified in the IPA.
  SHA-256 and bundle entitlements are in `build-23/ipa-verification.json`.
- The normal app was rebuilt and restored to the dark iPhone 17 Pro Max simulator
  after screenshot tests. Historical test-generated design-review assets were
  restored; the test plan and dependency lockfiles remain unchanged.
- Archive and IPA are outside Git at `/tmp/SatelliteForecast-2.1.0-23.*`.

## Refreshed home screenshots

All eight native dark-mode **1320 × 2868** home images were captured and reviewed.
Selection JSONs exactly match the pinned 2.0.0 build 20 observer/time-zone/TLE/pass
moments. Weather is an illustrative 16°C partly-cloudy UI fixture at each historical
clock, not a claimed historical observation. English formats 61°F; the other
locales format Celsius. French, Spanish, Portuguese and Russian use the shipped
compact weather fallback; English, Japanese, Korean and Chinese also show condition
text. Other screenshot slots were not regenerated. Build 24 uploaded the new weather home
images to the App Store draft alongside byte-identical copies of the other five
public slots, preserving their reviewed gallery order.

| Locale | Home screenshot |
| --- | --- |
| en-US | [Weather home](screenshots/en-US/01-forecast.png) |
| fr-FR | [Weather home](screenshots/fr-FR/01-forecast.png) |
| es-ES | [Weather home](screenshots/es-ES/01-forecast.png) |
| pt-BR | [Weather home](screenshots/pt-BR/01-forecast.png) |
| ru | [Weather home](screenshots/ru/01-forecast.png) |
| ja | [Weather home](screenshots/ja/01-forecast.png) |
| ko | [Weather home](screenshots/ko/01-forecast.png) |
| zh-Hans | [Weather home](screenshots/zh-Hans/01-forecast.png) |

Checksums, dimensions and illustrative weather inputs: `screenshot-verification.json`.
