# Screenshot and visual review

- Default to the iPhone 17 Pro Max simulator unless the user specifies a different simulator.
- Always capture and review app screenshots in dark mode.
- Do not spend time capturing, reviewing, or fixing light-mode appearance unless the user explicitly requests it.
- Set the simulator to dark mode before visual inspection.
- After every app code change, rebuild and rerun the app in the simulator so the updated version is available for review.

# App Store Connect releases

- Before preparing a release, uploading store screenshots, or publishing to TestFlight/App Store Connect, read [the publishing guide](Documentation/AppStore/PublishingGuide.md).
- Reuse [the reviewed screenshot moments](Documentation/AppStore/ScreenshotMoments.md) for locale-specific geography and impressive passes. Preserve each moment's TLEs, observer location, and time zone; regenerate and visually verify when inputs change.
- Use a new version-specific evidence directory and explicitly pass it to the capture/upload scripts. Their historical defaults must not overwrite an earlier release.
- Keep the guide and moment catalog updated with useful discoveries after future releases. Distinguish internal TestFlight availability, App Review submission, and public release in status reports.

# Product analytics

- Read [the analytics metric catalog](Documentation/Analytics.md) when changing screens, loading flows, onboarding, location selection, or alarms. Keep event semantics, conversion definitions, and measurement boundaries documented there.
- Reuse `AppAnalytics` and stable screen names. Never log coordinates, search text, tokens, notification identifiers, or raw error messages. Keep tests and routine Debug runs out of custom production telemetry.
