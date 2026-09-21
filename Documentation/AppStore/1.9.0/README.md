# 1.9.0 (11) — TestFlight

Prepared September 20, 2026 for internal First Light TestFlight distribution.

Includes the full accumulated planetarium and Sky Chart improvements: smoother
satellite motion, Earth-view planet phases and inclinations, physical Saturn
rings, century-range reference validation, Moon detail, improved sky backgrounds,
labels, tracking, and chart controls. Previous 1.8.0 review evidence is retained.

Validation: full behavior suite passed 107 tests, skipped 2 opt-in tests, and
failed 0 on iPhone 17 Pro Max. The initial run found two stale J2000 camera fixtures;
the fixtures now precess catalog coordinates to the rendered date, with all
assertions retained. Release archive and signed IPA export succeeded. Recent
visual evidence is in Documentation/DesignReview/Planetarium, including
AdaptiveSunLabel and CenturyAccuracy. The test plan was restored.

Build identity and IPA SHA-256 are recorded in build-identity.json. Archives and
IPAs remain outside Git. Build `85cec208-6fca-4385-b20e-479980328510` finished processing as VALID
and is IN_BETA_TESTING for internal First Light, with automatic notification
enabled. External state is READY_FOR_BETA_SUBMISSION; no external submission
was requested. Source commit: `943ae72`. Final remote responses are retained. This release does not request App Store review or release.
