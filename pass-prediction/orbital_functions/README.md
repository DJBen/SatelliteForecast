# Orbital data cache

`orbital_data?category=25544|48274|visual|active|last-30-days` serves allowlisted
public orbital data from the private `pass-prediction_tle` bucket. It never
fetches upstream on a user request. ISS/Tiangong remain TLE for existing backend
consumers; categories use OMM JSON to support six-digit catalog IDs.

`refresh_orbital_cache` runs at minute 17 every six hours. It validates payloads
before atomically replacing each GCS object, retries transient transport/5xx
failures at most twice, and leaves the previous object untouched on failure.
Failures propagate to Scheduler/Cloud Logging. HTTP 403/404/429 are not retried.
The endpoint serves last-known-good data for up to seven days since publication,
marks data older than twelve hours with X-Orbital-Stale, and returns an uncached
503 with Retry-After when the cache is absent or too old. Responses carry the
object update time and have a five-minute HTTP cache TTL.

Deploy from repository root:

    firebase deploy --only functions:orbital-cache --project pass-prediction

Test:

    orbital_functions/venv/bin/python -m unittest discover -s orbital_functions -p 'test_*.py'

Run a refresh:

    gcloud scheduler jobs run firebase-schedule-refresh_orbital_cache-us-central1 --project pass-prediction --location us-central1

After a successful first refresh of all five objects, pause the old
`populate-tle-iss-scheduler-trigger` and `populate-tle-tianhe-scheduler-trigger`
to avoid duplicate upstream polling. Their jobs remain available for rollback.
The new refresher maintains the same station object names used by existing
notification functions. No notification functions or user records are changed.

Diagnosis: iOS bypassed the existing cache; the private bucket was not readable
by apps; existing refresh jobs ran only for ISS/Tiangong every twelve hours;
CelesTrak intermittently timed out. The last-30-days TLE query returned 404 because
recent satellites require six-digit catalog IDs (unsupported by TLE). Modern
JSON preserves these IDs without truncation.
