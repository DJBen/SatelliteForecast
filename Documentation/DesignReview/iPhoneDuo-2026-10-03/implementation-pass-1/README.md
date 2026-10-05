# Duo implementation pass 1 and design review 2

Implemented against baseline `ed8180c3772b195bcc47d1aa497ae354df890bca` in the app working tree. The saved `implementation.patch` and its SHA-256 in `evidence.json` identify the changes. No release or App Store upload was performed.

## Implemented

- Reminder event names and exact times wrap on separate lines. The form scrolls, uses 0/5/10-minute presets plus custom hour/minute/second steppers, shows station/date context, and pins confirmation in the bottom safe area. Creation and existing-reminder titles use distinct localization keys. Existing reminders remain read-only with Delete.
- Confirmation awaits the notification service result. Submission is disabled while saving, repeated queued submissions are ignored, and the form remains open with an error on failure. Analytics conversion remains after OS acceptance and persistence.
- Orientation help lives below the pass chart, with a direct fixed-chart action and expanded guidance on request.
- Visible-pass rows show rise date/time, sunlit duration, direction and peak elevation without a fixed row height. The globe is collapsed behind a disclosure.
- Empty Alarms offers Choose a pass, which selects Forecast and uses its existing all-passes route. Edit is hidden when empty.
- Home's Enable alerts action precedes supporting statistics and the sky preview. Its caption explains automatic ISS/Tiangong push alerts. The preview shrinks and weather moves lower at accessibility sizes. This action still does not create a local one-off alarm.

## Verification

- Xcode 27.1 beta / iOS 27.1 beta; dedicated iPhone Duo simulator `7C40B063-AE4F-4981-9915-EDCD4DF343A5`.
- Rebuilt and reran after every production-code patch. Final normal app is running in dark mode; see `normal-app-final.log`.
- Final capture run: 7 NativeArchitectureTests plus the interactive screenshot capture test passed; see `capture-tests-final.log` and `/tmp/DuoImplementationPass1Final.xcresult`.
- 20 new dark-mode native outer-display screenshots: 14 screen states and 6 accessibility2 variants. Each PNG is 1398 × 2034 pixels, from a 466 × 678-point real simulator window. Frozen English/UTC orbital fixture permits comparison to the original review.
- The visual alarm fixture supplies Choose a pass without exercising its route. The form fixture does not connect to a live notification service. Screenshots do not establish permission behavior, scheduling success, notification delivery, or sensor accuracy.
- Temporary capture harness and test-plan edits were restored. The last follow-up code guard only prevents a queued duplicate submission; it does not change the captured layout.
- Draft QA captures are retained separately and excluded from the website. Final captures corrected the initial button contrast and oversized home-action wrapping.

## Second review

1. Validate inner display, rotation, book/tabletop folds and open/close continuity before claiming complete Duo support. Device Hub computer control remains unavailable.
2. Keep selected event and alert time beside the pinned confirmation button at larger text sizes.
3. Reduce secondary home information and give upcoming opportunities more space on wider windows.
4. Surface the next chart event earlier and stack timeline names/times at accessibility sizes.
5. Group compact pass rows by day and shorten repeated direction descriptions.
6. Add saved feedback and a Settings action for denied notifications; verify retry/repeated-tap behavior and delivery; translate new UI copy across supported locales.

The existing review website retains its audience and includes original Before evidence, 20 After captures, implementation status and revised suggestions. Its native inner-display concepts remain proposals.

Published review: https://satellite-iphone-duo-review.swifty-ben.chatgpt.site

Website source commit: `9fa29eb89174a4792e4180425c6810e2e0d55379`. Deployment `appgdep_6ac17f3b4d50819183670146de51344f` succeeded; existing owner-only audience preserved.
