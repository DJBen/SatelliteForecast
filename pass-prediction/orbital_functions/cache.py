"""Validated last-known-good orbital cache; user requests never hit upstream."""
from datetime import datetime, timezone
import requests
import json
import math
from google.cloud import storage
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

BUCKET = 'pass-prediction_tle'
SOURCES = {
    '25544': ('CATNR', '25544', 'tle_25544.txt'),
    '48274': ('CATNR', '48274', 'tle_48274.txt'),
    'visual': ('GROUP', 'visual', 'visual.json'),
    'active': ('GROUP', 'active', 'active.json'),
    'last-30-days': ('GROUP', 'last-30-days', 'last-30-days.json'),
}

def validate(text, satellite_id=None):
    lines = [line.rstrip() for line in text.splitlines() if line.strip()]
    if not lines or len(lines) % 3:
        raise ValueError('Incomplete or empty TLE data')
    for i in range(0, len(lines), 3):
        a, b = lines[i + 1:i + 3]
        if len(a) != 69 or len(b) != 69 or not a.startswith('1 ') or not b.startswith('2 '):
            raise ValueError('Invalid TLE line structure')
        if a[2:7] != b[2:7] or (satellite_id and a[2:7].strip() != satellite_id):
            raise ValueError('Unexpected satellite ID')
        for line in (a, b):
            checksum = sum(int(c) if c.isdigit() else 1 if c == '-' else 0 for c in line[:68]) % 10
            if not line[68].isdigit() or checksum != int(line[68]):
                raise ValueError('Invalid TLE checksum')
        epoch = float(a[20:32])
        if not 1 <= epoch < 367 or not 0 < float(b[52:63]) < 20:
            raise ValueError('Invalid orbital values')
    if satellite_id and len(lines) != 3:
        raise ValueError('Expected one satellite')
    return '\n'.join(lines) + '\n'

def validate_json(text):
    records = json.loads(text)
    if not isinstance(records, list) or not records:
        raise ValueError('Empty orbital JSON')
    for record in records:
        if not isinstance(record.get('NORAD_CAT_ID'), int) or record['NORAD_CAT_ID'] <= 0:
            raise ValueError('Invalid catalog ID')
        for name in ('OBJECT_NAME', 'OBJECT_ID', 'EPOCH'):
            if not isinstance(record.get(name), str): raise ValueError('Missing ' + name)
        datetime.fromisoformat(record['EPOCH'])
        for name in ('ECCENTRICITY', 'INCLINATION', 'RA_OF_ASC_NODE', 'ARG_OF_PERICENTER', 'MEAN_ANOMALY', 'MEAN_MOTION', 'BSTAR'):
            if not isinstance(record.get(name), (int, float)) or not math.isfinite(record[name]):
                raise ValueError('Invalid ' + name)
        if not 0 <= record['ECCENTRICITY'] < 1 or not 0 < record['MEAN_MOTION'] < 20:
            raise ValueError('Invalid orbit')
        for name in ('EPHEMERIS_TYPE', 'ELEMENT_SET_NO', 'REV_AT_EPOCH'):
            if not isinstance(record.get(name), int): raise ValueError('Missing ' + name)
        if not isinstance(record.get('CLASSIFICATION_TYPE'), str): raise ValueError('Missing classification')
    return json.dumps(records, separators=(',', ':'), allow_nan=False)

def refresh(client=None, session=None):
    client = client or storage.Client()
    if session is None:
        session = requests.Session()
        # Retry only transient failures. Never hammer 403/404 or rate limits.
        retry = Retry(total=2, backoff_factor=3, status_forcelist=[500, 502, 503, 504],
                      allowed_methods=['GET'], respect_retry_after_header=False)
        session.mount('https://', HTTPAdapter(max_retries=retry))
    failures = []
    for key, (field, value, filename) in SOURCES.items():
        try:
            response = session.get('https://celestrak.org/NORAD/elements/gp.php',
                                   params={field: value, 'FORMAT': 'TLE' if field == 'CATNR' else 'JSON'}, timeout=(15, 45))
            response.raise_for_status()
            data = validate(response.text, value) if field == 'CATNR' else validate_json(response.text)
            blob = client.bucket(BUCKET).blob(filename)
            blob.cache_control = 'private, max-age=0'
            blob.metadata = {'fetched_at': datetime.now(timezone.utc).isoformat(), 'source': 'celestrak'}
            blob.upload_from_string(data, content_type='text/plain; charset=utf-8' if field == 'CATNR' else 'application/json', timeout=30)
            print(f'Refreshed {key}: {len(data)} bytes', flush=True)
        except Exception as error:
            # Do not delete or overwrite the previous valid object on failure.
            failures.append(key)
            print(f'ERROR refreshing {key}: {error}', flush=True)
    if failures:
        raise RuntimeError('Refresh failed (previous cache retained): ' + ', '.join(failures))
