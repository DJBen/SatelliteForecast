# Manual alarm picker design review

Reviewed in dark mode on the iPhone 17 Pro Max simulator (iOS 27).

The form uses an explicit date/time wheel, a pass-moment menu, event/5-minute/10-minute shortcuts, and a persistent save action. Including the calendar date makes reminders across midnight visible. Existing alarms can be edited, with a separate red delete action. The form states that the local alarm uses the default notification sound.

The fixture captures cover all eight supported languages, a saved alarm, a 375 × 667 layout, and accessibility text size 3. Compact and accessibility captures include a scrolled view. Historical orbital fixtures keep these screenshots deterministic; their dates are not live predictions.

Validation:
- Five timing tests cover midnight, keeping lead time when changing moments, retaining the saved absolute time after prediction updates, missing illumination, and retaining longer legacy lead times during edits.
- The opt-in native view capture test passed and produced 13 reviewed dark screenshots.
- All eight localization files passed plist validation, with no duplicate keys.
- The live simulator shortcut changed the selected alarm from 6:37 AM to 6:32 AM. Tapping the native minute wheel also updated the displayed time from 6:37 AM to 6:36 AM; a custom time clears the shortcut selection.

Sound delivery and successful OS scheduling were not retested in this review: notification permission is disabled on this simulator. The existing notification service continues to request sound permission and use the default notification sound.

To regenerate the fixture captures, create `/tmp/satellite-alarm-picker-review`, run `ScreenSnapshotTests/testAlarmPickerDesignReview`, then remove the marker. Ordinary test runs skip this visual capture.
