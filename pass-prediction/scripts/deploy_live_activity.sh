#!/usr/bin/env bash
# Deploy only the Live Activity pipeline; existing reminders are untouched.
set -euo pipefail
cd "$(dirname "$0")/.."
project=pass-prediction
region=us-central1
runtime_account=388502820521-compute@developer.gserviceaccount.com
task_account=live-activity-tasks@${project}.iam.gserviceaccount.com
if ! gcloud iam service-accounts describe "$task_account" --project="$project" >/dev/null 2>&1; then
  gcloud iam service-accounts create live-activity-tasks --project="$project" --display-name='Live Activity task invoker'
fi
gcloud iam service-accounts add-iam-policy-binding "$task_account" --project="$project" \
  --member="serviceAccount:$runtime_account" --role=roles/iam.serviceAccountUser --quiet
if ! gcloud tasks queues describe station-live-activities --project="$project" --location="$region" >/dev/null 2>&1; then
  gcloud tasks queues create station-live-activities --project="$project" --location="$region"
fi
gcloud tasks queues update station-live-activities --project="$project" --location="$region" \
  --max-concurrent-dispatches=10 --max-dispatches-per-second=5 \
  --max-attempts=10 --min-backoff=2s --max-backoff=60s --max-retry-duration=600s
functions/venv/bin/python -m unittest discover -s tests -p 'test_live_activity.py'
FUNCTIONS_DISCOVERY_TIMEOUT=60 PATH="$PWD/functions/venv/bin:$PATH" firebase deploy \
  --only functions:register_live_activity,functions:deliver_live_activity --project "$project" --non-interactive
gcloud run services add-iam-policy-binding deliver-live-activity --project="$project" --region="$region" \
  --member="serviceAccount:$task_account" --role=roles/run.invoker --quiet
gcloud firestore fields ttls update expires_at --collection-group=station_live_activities \
  --enable-ttl --project="$project" --async --quiet
