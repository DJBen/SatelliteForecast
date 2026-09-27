#!/usr/bin/env bash
# Stage only the scheduler and shared policy/outbox modules for Cloud Run's buildpack.
set -euo pipefail
cd "$(dirname "$0")/.."
staging=$(mktemp -d)
trap 'rm -rf "$staging"' EXIT
cp jobs/schedule_notifications/{main.py,requirements.txt,Procfile,.gcloudignore} "$staging/"
mkdir "$staging/common"
cp functions/common/{__init__.py,activity.py,notification_scheduler.py} "$staging/common/"
gcloud run jobs deploy schedule-notifications --source="$staging" \
    --project=pass-prediction --region=us-central1 --tasks=1 --max-retries=1 \
    --task-timeout=900s --quiet
