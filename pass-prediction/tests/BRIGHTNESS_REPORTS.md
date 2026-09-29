# Satellite brightness reports

`POST report_satellite_brightness` requires an `X-Firebase-AppCheck` token.
The body contains `id` (UUID, reused on retry), `installationID` (persisted random
UUID), `fcmToken` (current raw push registration), `noradID`, `magnitude` (0–5),
and `observedAt` (Unix seconds, within the past day and no more than five minutes
in the future). No coordinates are submitted.

`satellite_brightness_reports` stores the NORAD ID, magnitude, observation and
server receipt times, installation ID as `reporter_id`, raw `fcm_token`, and schema
version. The installation ID identifies a client installation, not an authenticated
person; FCM tokens can rotate. Neither is treated as an authentication credential.
The document ID namespaces the request UUID by installation. Repeating the same
submission is idempotent; a conflicting payload is rejected. A transactional
installation limit permits 10 new reports per minute. Do not log bodies or tokens.

The deployed Firestore rules were inspected: only `/users/{push_token}` has client
access; the new collections are denied by default. The Admin SDK writes through
the App-Check-protected endpoint. No existing rules or other functions are changed.

Run `functions/venv/bin/python -m unittest discover -s tests -p test_brightness_reports.py`.
Deploy only `functions:report_satellite_brightness` to project `pass-prediction`.
