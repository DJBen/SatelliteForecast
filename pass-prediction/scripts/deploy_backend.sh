#!/usr/bin/env bash
# Reconcile this project's backend configuration; never purge pending tasks.
set -euo pipefail
cd "$(dirname "$0")/.."
project=pass-prediction
region=us-central1
runtime_account=388502820521-compute@developer.gserviceaccount.com
if ! gcloud tasks queues describe pass-predictions --project="$project" --location="$region" >/dev/null 2>&1; then
    gcloud tasks queues create pass-predictions --project="$project" --location="$region"
    gcloud tasks queues pause pass-predictions --project="$project" --location="$region"
fi
gcloud tasks queues update pass-predictions --project="$project" --location="$region" \
    --max-concurrent-dispatches=20 --max-dispatches-per-second=5 \
    --max-attempts=10 --min-backoff=30s --max-backoff=300s --max-retry-duration=3600s
uv venv --python 3.13 --allow-existing functions/venv
uv pip install --python functions/venv/bin/python -r functions/requirements.txt
uv venv --python 3.13 --allow-existing orbital_functions/venv
uv pip install --python orbital_functions/venv/bin/python -r orbital_functions/requirements.txt
functions/venv/bin/python -m unittest discover -s tests -p 'test_*.py'
orbital_functions/venv/bin/python -m unittest discover -s orbital_functions -p 'test_*.py'
PATH="$PWD/functions/venv/bin:$PATH" firebase deploy --only functions --project "$project" --non-interactive
gcloud run services add-iam-policy-binding process-prediction-region --project="$project" --region="$region" \
    --member="serviceAccount:$runtime_account" --role=roles/run.invoker --quiet
gcloud run jobs deploy schedule-notifications --source=jobs/schedule_notifications \
    --project="$project" --region="$region" --tasks=1 --max-retries=1 --task-timeout=900s --quiet
gcloud scheduler jobs update http schedule-notifications-scheduler-trigger \
    --project="$project" --location="$region" --schedule='*/15 * * * *' --time-zone=UTC
gcloud firestore fields ttls update expires_at --collection-group=tasks --enable-ttl --project="$project" --async --quiet
gcloud firestore fields ttls update expires_at --collection-group=records --enable-ttl --project="$project" --async --quiet
gcloud tasks queues resume pass-predictions --project="$project" --location="$region"
