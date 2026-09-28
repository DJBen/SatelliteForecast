# 2.0.0 build 19 — latest-main replacement

Built after widget fix `d5b3fa3` merged into main, as requested. Includes the
planetarium responsiveness fix, filled-eye selection, realtime pass arc and elevation,
shared coral passing-now shimmer, debug clock support, automatic Now mode during a
pass, and remote Live Activity updates from `195a4cb`.

The widget fix preserves its saved forecast across relaunches and GPS jitter; moving
more than 25 km invalidates it. Chinese installed and App Store names are **天宫过境**.

Build 16's review submission was withdrawn. Builds 17 and 18 were uploaded but never
submitted; this candidate replaces them. Public release remains manual.

Fresh in-app captures use the reviewed locale moments in dark mode on iPhone 17 Pro
Max. Final screenshot checks and submission records are in build 20.

## Verification setup

Behavior suite: 132 passed, 2 optional reviews skipped, zero failures. Archive and
export succeeded with production APNs/App Attest signing and the Chinese display
name verified in the exported IPA.

A concurrent local build interrupted the initial screenshot test on the shared
simulator. Captures restarted on a clone of the same iPhone 17 Pro Max:
`0DB01E7A-D65B-47B3-BBDE-5CDD10BC9858`, named “iPhone 17 Pro Max — App Store 19”.
The clone retains the prepared Home Screen widget layout and uses dark mode.

## Superseded before submission

Build 19 was uploaded and validated but not submitted. Commit `26d4767` then
landed with the per-place widget cache and coral Passing label. Build 20 includes
that latest main. Fresh screenshots from this preparation are retained with build 20;
in-app slots are visually unchanged by the widget-only follow-up.
