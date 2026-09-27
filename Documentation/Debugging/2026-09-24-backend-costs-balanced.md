# Balanced backend cost policy — 2026-09-24

## Diagnosis

Cloud Monitoring showed a sharp increase after the September 21 backend rollout.
The coordinator queued every known region every quarter hour, then workers read
orbital files and Firestore before discovering that predictions were fresh.
September 23 (America/Los_Angeles) had 191,536 prediction-worker requests,
141,611 billable instance-seconds, 1,679,499 Firestore reads, 225,065 writes,
and approximately 958,000 orbital-bucket read/metadata operations. In one
15-minute worker log sample, 1,993 of 1,995 calls updated no satellites.
These explain a usage increase, not an exact reconciliation of the reported $10:
the existing billing-export dataset had no tables.

## Changes

- Prediction sweeps run at 00:30, 06:30, 12:30 and 18:30 UTC, after the existing
  six-hour orbital refresh. Batched coverage checks enqueue only stale regions.
- Server alerts require a launch in the previous 30 days and exclude disabled
  and Debug registrations. Missing launch timestamps have a fixed grace deadline
  of October 8 at 00:00 UTC. No registrations were deleted.
- The eligibility preview found 501 recent registrations out of 2,450;
  483 had usable locations spanning 465 regions. All registrations had launch
  timestamps, so the missing-timestamp grace period is currently unused.
- Returning users and location changes reconcile alerts immediately when cached
  predictions are fresh; otherwise regional workers calculate and reconcile.
  Queued workers skip regions without eligible users.
- Orbital files are reused for five minutes per warm process.
- Notification reconciliation runs hourly and still queues a rolling 24-hour
  window. Existing Cloud Tasks retain their due times.
- A transactionally guarded creation receipt skips confirmed, unchanged tasks.
  Failed or interrupted creation can retry; a stale confirmation cannot mark a
  newer task as created.
- The job and functions share one eligibility policy and scheduler implementation;
  the deployment helper stages those modules into the Cloud Run build context.

## Product tradeoffs

Dormant devices stop getting automatic backend alerts until their next launch.
Orbital corrections and repair of missed registration triggers can wait for the
next six-hour sweep; immediate launch processing remains best effort. Manual
on-device alarms and their Analytics conversion semantics are unchanged. No iOS
code was changed or release required. Previously queued notification tasks are
not purged; delivery checks current eligibility.

## Validation

48 backend tests passed, including activity boundaries, the fixed grace period,
source-cache expiry, batched stale checks, returning-user reconciliation,
inactive queued work, interrupted creation, and stale confirmation races.

The production coordinator completed at 2026-09-24 07:41:19 UTC: 2,450 scanned,
483 eligible with locations, 465 regions, zero stale, zero queued. The old policy
would have queued approximately 2,000 workers regardless of freshness.

Authenticated production worker calls returned HTTP 200. The first reconciled
one task with zero prediction updates; the repeat reconciled zero tasks with
zero updates. The private worker's Cloud Tasks service-account invoker binding
was restored after Firebase deployment and verified.

Both production schedules were verified enabled with the new UTC cadences.
Cloud Run execution `schedule-notifications-kvpjp` succeeded. At 07:46:05 UTC,
its completion log reported 2,450 scanned registrations, 18 invalid locations,
459 task reconciliations and zero errors. The 18 invalid locations explain the
difference between 501 recently active registrations and 483 eligible devices
with usable locations. The container exited with status 0.

The deployed job image digest is
`sha256:218a8516f11035cad21b476d50d053408a897a5c452fd7b2cf940d22a9a9546e`.
All five changed functions reported ACTIVE following deployment. No live test
registrations or synthetic push notifications were created; the worker checks
reconciled an existing eligible region's normal scheduled alerts.

## Reproduction and deployment

Run `functions/venv/bin/python -m unittest discover -s tests -p 'test_*.py'`
from `pass-prediction`. `scripts/deploy_backend.sh` deploys the functions, restores
the private worker binding, stages/deploys the job and sets its hourly schedule.
For a job-only update use `scripts/deploy_notification_job.sh`; the job directory
alone no longer contains the shared modules.

Operational counters are not custom production Analytics events. Compare daily
worker calls, Cloud Run billable time, Firestore operations and actual billing
line items after rollout; no dollar-savings guarantee is inferred from invocation
counts alone. Raw CLI deployment logs and configuration snapshots from this run
are retained locally under `/tmp/balanced-backend-rollout/`.
