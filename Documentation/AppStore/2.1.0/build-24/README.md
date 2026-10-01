# iOS 2.1.0 build 24 — App Store preparation

Build **24** (`5c463010-9438-421b-91fe-c613836c51a0`) is **VALID**, available on
internal **First Light** TestFlight (`IN_BETA_TESTING`), and attached to App Store
version `51de3472-bfd1-434c-ba5e-c1d963719301`. Export explicitly sets
`testFlightInternalTestingOnly=false`; the external beta state is
`READY_FOR_BETA_SUBMISSION`. No external beta group was assigned.

The App Store draft is **PREPARE_FOR_SUBMISSION** with **AFTER_APPROVAL** selected
and read back. Automatic release is configured; **App Review submission has not
been made**, and version 2.0.1 remains the public release.

## Remaining access requirement

The live App Store listing checked October 1 still declares **Data Not Collected**,
including after version 2.0.1 became public. This conflicts with the app's retained
reminder locations, identifiers, brightness reports, analytics, and anonymous weather
account. Safari App Store Connect and the CLI web session are signed out. Safari's
saved sign-in requires user authentication. At the final browser check, the Mac was
locked and Computer Use could not automatically unlock it. The public API cannot read or edit this
label. The user has been asked to sign in so the declaration can be corrected before
submission; no additional release approval is required.

`privacy-declaration-plan.json` prepares the data categories, purposes, linkage and
tracking answers using app source, the deployed policy, Apple's definitions and
Firebase's SDK disclosure documentation. It is **not applied or published**. It adds
User ID for Firebase's persistent anonymous weather account to the earlier release's
six-category assessment. `privacy-public-check.json` records the current public label.
API validation has zero errors, zero warnings and one informational privacy check;
`submission-preview.json` confirms the already attached build would be submitted.

## Screenshots and metadata

Eight locales each have six verified APP_IPHONE_67 images. Their weather home image
comes from the reviewed `2.1.0/screenshots/` capture; the other five slots are byte-for-
byte identical to the previous public gallery. Widget-first order is preserved:
widgets, weather home, planetarium, pass chart, pass list, satellites.

Every inherited image was verified against build 20 before replacement. The upload
runner reuploads each six-image set to preserve that order, checks COMPLETE and ordered
MD5s, and a subsequent run reports `already matches` for all eight locales. Selection
moments and illustrative 16°C partly-cloudy weather remain unchanged. Screenshot
symlinks reference the original reviewed PNGs without duplicating 127 MB of assets;
`screenshot-sources.json` records their paths and hashes. Fresh initial and final remote
inventories and upload results are saved here.

Version metadata was copied from public 2.0.1, with new release notes in all eight
locales. Release notes and What to Test notes were read back and verified. Final App
Review instructions cover home weather, automatic rain suppression, manual reminders,
the live planetarium and optional brightness reports. Existing contact details were
retained and not copied into release evidence; no demo account is needed.

## Validation and source

- iPhone 17 Pro Max / iOS 27: **154 passed**, zero failed, three optional fixtures skipped
  (157 total). Localization audit: 389 implementation and two public strings in eight locales.
- App and widget: **2.1.0 (24)**; four version/build settings agree. The only app source
  change from build 23 is the build number. All weather/backend work was already on main.
- Archive/export succeeded. Both code signatures, App Group, production APNs and disabled
  debugging were verified. IPA SHA-256 and bundle verification are recorded here.
- Normal app rebuilt, rerun, and visually reviewed in the dark iPhone 17 Pro Max simulator;
  `simulator-home-dark.jpg` shows live weather. Test plan and dependency lockfiles unchanged.
  Nineteen incidental design-review test artifacts restored to their pre-run contents.
- Archive and IPA remain outside Git: `/tmp/SatelliteForecast-2.1.0-24.xcarchive` and
  `/tmp/SatelliteForecast-2.1.0-24.ipa`. Upload was committed once and processed COMPLETE.

After authenticated privacy correction, run the already authorized submission:

```sh
asc review submit --app 1578649430 --version-id 51de3472-bfd1-434c-ba5e-c1d963719301 --build 5c463010-9438-421b-91fe-c613836c51a0 --confirm
```

Read back the review submission and version state, retain AFTER_APPROVAL, and update
this record. WAITING_FOR_REVIEW is distinct from approval and automatic public release.
