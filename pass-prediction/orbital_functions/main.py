from datetime import datetime, timezone
from firebase_functions import https_fn, scheduler_fn
from google.cloud import storage
from cache import BUCKET, SOURCES, validate, validate_json, refresh

@https_fn.on_request(region='us-central1', invoker='public', max_instances=10, timeout_sec=30)
def orbital_data(request):
    """Expose only allowlisted public orbital data from the private bucket."""
    if request.method not in ('GET', 'HEAD'):
        return https_fn.Response('Method not allowed', status=405, headers={'Allow': 'GET, HEAD'})
    key = request.args.get('category', '')
    if key not in SOURCES:
        return https_fn.Response('Unknown category', status=400)
    field, value, filename = SOURCES[key]
    try:
        blob = storage.Client().bucket(BUCKET).get_blob(filename, timeout=10)
        if blob is None:
            raise ValueError('Cache not populated')
        # Read this exact generation, so freshness headers match the response bytes.
        raw = blob.download_as_text(timeout=15, if_generation_match=blob.generation)
        text = validate(raw, value) if field == 'CATNR' else validate_json(raw)
        age = max(0, int((datetime.now(timezone.utc) - blob.updated).total_seconds()))
        # Retain data through outages, but never serve arbitrarily old predictions.
        if age > 7 * 86400:
            raise ValueError('Cache older than seven days')
        headers = {'Cache-Control': 'public, max-age=300, stale-if-error=3600',
                   'X-Orbital-Updated': blob.updated.isoformat(),
                   'X-Orbital-Age': str(age), 'X-Orbital-Stale': str(age > 12 * 3600).lower()}
        return https_fn.Response(text if request.method == 'GET' else '', status=200,
                                 content_type='text/plain; charset=utf-8' if field == 'CATNR' else 'application/json', headers=headers)
    except Exception as error:
        print(f'ERROR reading orbital cache {key}: {error}', flush=True)
        return https_fn.Response('Orbital cache temporarily unavailable', status=503,
                                 headers={'Cache-Control': 'no-store', 'Retry-After': '300'})

@scheduler_fn.on_schedule(schedule='17 */6 * * *', region='us-central1',
                          timeout_sec=540, max_instances=1, retry_count=0)
def refresh_orbital_cache(event):
    refresh()
