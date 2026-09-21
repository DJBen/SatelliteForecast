# 1.8.0 (9): stable planetarium star labels

Analyzed the supplied September 20 screen recording at half-second intervals. The changing viewport admitted edge stars into a hard per-frame brightness budget, displacing names inside the view. Stateless rectangle collision checks also had no margin hysteresis.

The new screen-space layout retains readable incumbents, admits new labels only after 250 ms of uninterrupted extra clearance, fades them in over 200 ms, and applies a 600 ms cooldown after collision suppression. Existing names use tighter exit padding than entering names. Actual text collisions hide immediately to avoid overlapping even during transitions. Active candidates are retained beyond the 24-candidate ranking cutoff; daylight and the label toggle clear layout state.

Verification: iPhone 17 Pro Max simulator in dark mode; 104 behavior tests, 102 passed, zero failures, two opt-in tests skipped. A further real-renderer regression passed 120 small camera movements across repeated candidate refreshes while retaining a locally bright star outside the top 50. The deterministic layout test covers brighter newcomers, 240 jitter frames, 120 collision-boundary frames, and 601 dense-field frames with bounds/no-overlap assertions. Reviewed wide and close-zoom Metal screenshots, saved here. This is simulator verification, not a claim of physical-device frame-rate measurement.

Archived/exported 1.8.0 (9) with pinned dependencies. Build ID `7d50fd5f-c4aa-49ae-aa32-b194d55c6cb3` is VALID and both internal/external TestFlight are IN_BETA_TESTING, with auto-notification enabled. Localized What to Test notes were saved in all eight languages.

Build 8 was IN_REVIEW at the start; Apple approved it during this task and it now reports PENDING_DEVELOPER_RELEASE. No action was taken on its App Store submission or manual release. Build 9 is a TestFlight follow-up and is not attached to the approved App Store version.
