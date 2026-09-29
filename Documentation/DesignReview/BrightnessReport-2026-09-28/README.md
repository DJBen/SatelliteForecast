# Brightness reporting

Single-tapping the selected live satellite's details text opens a report sheet.
The satellite identity and observation timestamp are captured when opening it.
The slider spans 0–5 in 0.1 increments and changes the approximate visual guidance.
Lower magnitude means brighter; sky conditions affect visibility. Vega (~0) and
Polaris (~2) are rough comparison references, not precision calibration.

Report uploads NORAD ID, magnitude, observation time, persisted random installation
ID, and the current raw FCM token. The backend records server receipt time. The
FCM token is private report data, never an analytics parameter. App Check protects
the endpoint; existing Firestore rules deny direct access to report collections.

The UI shows sending, retry, and confirmed success states. Retries retain the
same request UUID and magnitude so an uncertain network outcome cannot duplicate
the report or change a previously accepted value. Simulator/test uploads are
blocked to keep fabricated observations out of production.

Backend tests cover validation, bounds, invalid attestation, rate limiting,
idempotency/conflicts, and endpoint error status. The dark iPhone 17 Pro Max visual
fixture shows the dialog in `dialog-dark.png`; interactive tap/slider automation
remains unavailable due to the Xcode 27 input-tool incompatibility.

Magnitude reference: https://homepage.physics.uiowa.edu/~spangler/29137_09/Manual_2950.pdf
App Check reference: https://firebase.google.com/docs/app-check/custom-resource-backend

Deployment completed for `report_satellite_brightness` in `us-central1`, project `pass-prediction`. The live endpoint returned HTTP 401 to an unattested POST as expected. Five backend unit tests passed. Simulator and device builds passed; installed and launched on the connected iPhone. No successful real observation upload was performed during this review.

The Report/Retry button now uses native glass styling with a semibold light label. Reviewed `glass-button-dark.png` in dark mode; simulator and device builds succeeded, and the app was installed and launched on the connected iPhone.
