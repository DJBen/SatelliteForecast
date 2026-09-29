# App Privacy follow-up

The public App Store page fetched on 2026-09-28 still states “Data Not Collected”.
That does not describe the current app. The API validation cannot verify or edit
this declaration. Both the in-app browser and asc web session were signed out.
An authenticated website session is required before the release submission.

Use https://appstoreconnect.apple.com/apps/1578649430/appPrivacy and Apple's definitions:
https://developer.apple.com/app-store/app-privacy-details/

The following collection is supported by the current source and the public policy:

| Data | Use | Association |
| --- | --- | --- |
| Precise location | Server-generated optional station reminders | Push/device identifier |
| Coarse location | Reminder grouping; Firebase Analytics approximate country/region | Push/device or analytics installation |
| Device ID | Push/Live Activity delivery, report identity, abuse prevention, Firebase Analytics | Installation/device |
| Other User Content | Optional satellite brightness observations and observation timestamps | Installation ID and raw FCM token |
| Product Interaction | Firebase Analytics screen and interaction events | Analytics installation |
| Performance Data | Forecast/catalog loading durations and result status | Analytics installation |

No advertising or cross-company tracking is implemented. Installation-level
pseudonymous IDs are not de-identified when they remain associated with the data.
Review the Firebase SDK's own collection along with the app's custom events when
entering the declaration. Do not select “not linked” merely because there is no
account or real name.

The public policy now describes brightness reports separately, at:
https://space-station-passes.web.app/privacy#brightness
