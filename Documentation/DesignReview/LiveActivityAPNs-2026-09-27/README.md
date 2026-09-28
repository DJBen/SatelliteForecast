# Live Activity APNs verification — September 27, 2026

Deployed to Firebase project `pass-prediction` and verified on the wired iPhone
running iOS 27. The Debug test disables every local phase update. The app was
backgrounded into Settings for shadow entry, sunlight entry, the final shadow
entry, and ending. Resuming the same process recorded the pending ActivityKit
content updates; see `device-receipts.json`. The phone was then relaunched normally
without the test flag. No push tokens, cancellation secrets or coordinates appear
in this evidence.

- Backend suite: 59 passed (10 Live Activity tests).
- Simulator: Live Activity state/localization and system lifecycle tests both passed.
- Simulator and signed physical-device builds passed; installed on the wired iPhone.
- App Check registration: real request accepted (204); missing attestation rejected (401).
- Private delivery: missing OIDC rejected (403); authenticated queue smoke test passed (204).
- Real phone received `upcoming → shadow → visible → shadow → ended` through APNs.
- Server removed delivery tokens after ending. TTL cleans the remaining receipt.

Not yet verified: a TestFlight/distribution build, locked-screen visual presentation,
force-quit delivery, offline recovery, live token rotation, and a remotely updated
scheduled start on a physical device. Unit tests cover revision ordering, cancellation
races and late delivery; the simulator covers local scheduled presentation.
