import os
import subprocess
from invoke import task

# Environment variables
GOOGLE_CLOUD_PROJECT = os.environ.get("GOOGLE_CLOUD_PROJECT")
REGION = os.environ.get("REGION", "us-central1")

# ISS: 25544
# Tianhe: 48274

@task()
def deploy_populate_tle_jobs(c, tasks=1, max_retries=1):
    """
    Deploy two copie of populate_tle jobs on Google Cloud Run Jobs.
    
    Args:
        tasks: Number of tasks to run in parallel
        max_retries: Maximum number of retries for a failed task
    """
    if not GOOGLE_CLOUD_PROJECT:
        raise ValueError("GOOGLE_CLOUD_PROJECT environment variable is not set")
    
    command = f"""
        gcloud run jobs deploy populate-tle-iss \
        --source populate_tle \
        --set-env-vars SATELLITE_ID=25544 \
        --tasks {tasks} \
        --max-retries {max_retries} \
        --region {REGION} \
        --project {GOOGLE_CLOUD_PROJECT}
    """
    c.run(command)

    command = f"""
        gcloud run jobs deploy populate-tle-tianhe \
        --source populate_tle \
        --set-env-vars SATELLITE_ID=48274 \
        --tasks {tasks} \
        --max-retries {max_retries} \
        --region {REGION} \
        --project {GOOGLE_CLOUD_PROJECT}
    """
    c.run(command)

@task()
def execute_populate_tle_jobs(c):
    """
    Execute two copie of populate_tle jobs on Google Cloud Run Jobs.
    """
    if not GOOGLE_CLOUD_PROJECT:
        raise ValueError("GOOGLE_CLOUD_PROJECT environment variable is not set")
    
    command = f"""
        gcloud run jobs execute populate-tle-iss \
        --region {REGION}
    """
    c.run(command)

    command = f"""
        gcloud run jobs execute populate-tle-tianhe \
        --region {REGION}
    """
    c.run(command)

@task()
def deploy_schedule_notifications_job(c):
    """
    Deploy the schedule_notifications job on Google Cloud Run Jobs.
    """
    if not GOOGLE_CLOUD_PROJECT:
        raise ValueError("GOOGLE_CLOUD_PROJECT environment variable is not set")
    
    command = f"""
        gcloud run jobs deploy schedule-notifications \
        --source schedule_notifications \
        --tasks 1 \
        --max-retries 0 \
        --region {REGION} \
        --project {GOOGLE_CLOUD_PROJECT}
    """
    c.run(command)

@task()
def execute_schedule_notifications_job(c):
    """
    Execute the schedule_notifications job on Google Cloud Run Jobs.
    """
    if not GOOGLE_CLOUD_PROJECT:
        raise ValueError("GOOGLE_CLOUD_PROJECT environment variable is not set")
    
    command = f"""
        gcloud run jobs execute schedule-notifications \
        --region {REGION}
    """
    c.run(command)

@task()
def deploy_delete_old_transits_job(c):
    """
    Deploy the delete_old_transits job on Google Cloud Run Jobs.
    """
    if not GOOGLE_CLOUD_PROJECT:
        raise ValueError("GOOGLE_CLOUD_PROJECT environment variable is not set")
    
    command = f"""
        gcloud run jobs deploy delete-old-transits \
        --source delete_old_transits \
        --tasks 1 \
        --max-retries 0 \
        --region {REGION} \
        --project {GOOGLE_CLOUD_PROJECT}
    """
    c.run(command)

@task()
def execute_delete_old_transits_job(c):
    """
    Execute the delete_old_transits job on Google Cloud Run Jobs.
    """
    if not GOOGLE_CLOUD_PROJECT:
        raise ValueError("GOOGLE_CLOUD_PROJECT environment variable is not set")
    
    command = f"""
        gcloud run jobs execute delete-old-transits \
        --region {REGION}
    """
    c.run(command)

