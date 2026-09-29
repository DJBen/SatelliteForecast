# 2.0.1 build 22

Release includes the live Sky now tab from build 21 and the subsequent selection,
centering, path/arrow, full active catalog, search and distance/illumination filters,
brightness reporting, observer-camera preservation, tab icon and navigation fixes.
App and widget versions are both 2.0.1 (22).

Validation: behavior suite 151 total, 148 passed, 0 failed, 3 optional review
fixtures skipped on iPhone 17 Pro Max / iOS 27. Five brightness backend tests
passed. Localization audit passed (359 Impl strings across eight locales).
Release archive succeeded. Prior targeted navigation checks verified animated
push and Back synchronization for all three satellite categories.

Store screenshots were explicitly not refreshed. All eight locales inherited
six APP_IPHONE_67 screenshots each from 2.0.0. Metadata and localized release notes
are included alongside this document. Release type is AFTER_APPROVAL.

Brightness endpoint was deployed and verified to reject unattested requests.
No fabricated report was submitted to production. The privacy page was updated
and deployed to describe voluntary observation data, installation identity and
raw FCM token storage. App Store privacy declaration requires a website session
and is not verifiable through the public App Store Connect API.

The build 21 TestFlight crash investigation found a Firebase Analytics
experiment-response stack. This release does not claim to fix that unproven
third-party crash. Raw device diagnostics remain private under .local/.

Published to `main` via PR #87, merge commit
`4d6d91144ccac139fe56b714ebb94cde4a28e7dd`. Export succeeded. Build `90d7346a-87ba-466a-8f3c-aad4a6965f40` completed processing
as VALID, is attached to the 2.0.1 App Store draft, and is IN_BETA_TESTING for the
internal group. ASC validation reports zero errors and zero warnings, with one
App Privacy verification notice. Public release submission is pending the App
Privacy correction described in `privacy-review.md`; it has not been submitted
to App Review. AFTER_APPROVAL remains configured for automatic release once
submitted and approved.
