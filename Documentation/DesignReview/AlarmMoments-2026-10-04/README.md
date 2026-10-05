# Alarm moment and picker simplification — October 4, 2026

Removed the At event / 5 min before / 10 min before shortcuts and the sound explanation from the shared alarm editor. Notifications still use the default sound.

Added Reaches 10° for the first ascending crossing. Pass generation refines the crossing with SGP4 propagation to a bracket under 0.1 seconds and stores the result in the Codable pass. The optional field preserves compatibility with older saved passes. Such passes omit this option until a new prediction is opened; no approximate crossing is fabricated.

Pass end is no longer selectable. Existing pass-end alarms retain their scheduled absolute date when opened, with rise used as the editing anchor. Notification identities and analytics acceptance boundaries are unchanged.

Validation:
- Debug simulator and physical-device builds succeeded.
- Rebuilt and ran on the iPhone 17 Pro Max simulator in dark mode.
- 13 targeted tests passed: draft scheduling, midnight handling, persistence, legacy pass end, permission/storage behavior, orbital 10° crossing, and visual fixtures.
- Dark screenshots cover eight locales, new and saved alarms, narrow screens, and accessibility text. The narrow picker scrolls above the pinned action; large text keeps all controls reachable.
- Installed and launched on Sihao’s iPhone, process 18712. These are local Debug changes, not a new TestFlight release.
