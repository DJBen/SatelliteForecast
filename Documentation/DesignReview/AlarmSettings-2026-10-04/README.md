# Editing alarms from Settings

Saved rows under Settings → Manage alarms open the same `PassAlarmSettingsModalView` used by pass detail. Rows have a chevron and an Edit alarm accessibility hint. The sheet uses the saved pass and observer, so opening it needs no orbital-data request. Saving uses the shared notification service and the same notification identifier; edits without chart snapshots retain the existing notification content and attachment.

Reviewed on iPhone 17 Pro Max (iOS 27), in dark mode:
- Opened Manage alarms and tapped a saved row; the editor selected the original time and pass moment.
- Changed from 5 minutes before to 10 minutes before; Save changes became enabled.
- Cancelled and reopened; the original time was restored and Save changes was disabled.
- Deleted from the sheet; it dismissed, the list showed its empty state, and the shared service and persisted alarm list were empty.

Seven targeted tests passed: six alarm draft/context checks and the interactive Settings flow. Fixture alarms use a historical pass and an isolated defaults suite; they are not production data. The normal app was rebuilt and rerun after testing.

OS rescheduling and attachment retention were not exercised end to end because notification permission is disabled on this simulator. The existing permission and future-time validation remain in the shared service.

The three screenshots show the list, its editor and the list after deletion. Create `/tmp/satellite-alarm-settings-review` to run `ScreenSnapshotTests/testInteractiveAlarmSettingsEditing`; after changing a time and cancelling, write `cancelled` to the marker to verify the original alarm remains. Delete from the sheet, then remove the marker to finish and verify deletion/persistence.
