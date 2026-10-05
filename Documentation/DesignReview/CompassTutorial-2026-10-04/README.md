# Alarm rows and first Compass tutorial — October 4, 2026

Removed the speaker badge and its accessibility label from saved alarm rows. The existing notification sound remains enabled.

Moved automatic Skychart video presentation from the visible-pass destination wrapper into the shared PassView. Both Passes and Satellites use this view. The tutorial follows Compass activation, regardless of visibility, using the existing hasCompletedAllPassesOnboarding flag. It is suppressed for people who already saw the video, including manual help replay. New installations default to Compass off; previously stored preferences are preserved. Entering with an already-enabled saved Compass preference presents an unseen tutorial. Cancelling Compass within the presentation delay leaves the tutorial unseen.

Validation:
- Simulator and physical iPhone Debug builds passed.
- Rebuilt and reran on the default iPhone 17 Pro Max simulator in dark mode.
- Four targeted tests passed: the actual shared pass chart presents only for first enabled Compass use, cancellation does not consume the tutorial, list discovery does not consume it, and alarm-row visual fixtures render across eight locales, narrow screens, and accessibility text.
- Reviewed the video, disabled-Compass chart, and simplified alarm rows in dark screenshots.
- Installed and launched on Sihao’s iPhone, process 18733. This delivery is a local Debug build; no new TestFlight upload was made.
