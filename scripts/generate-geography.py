#!/usr/bin/env python3
"""Build an offline, multilingual gazetteer from public-domain Natural Earth v5.1.2."""
import json
from pathlib import Path
from urllib.request import urlopen

root = Path(__file__).resolve().parents[1]
languages = ['en', 'fr', 'es', 'pt', 'ru', 'ja', 'ko', 'zh']
# Large countries where a first-level region adds useful, recognizable context.
subdivision_countries = ['US', 'CA', 'MX', 'BR', 'AR', 'RU', 'CN', 'IN', 'AU', 'ID', 'KZ', 'SA']
regions, places = [], {}
for layer, kind in [('ne_10m_admin_0_countries', 'land'), ('ne_10m_geography_marine_polys', 'water')]:
    url = f'https://raw.githubusercontent.com/nvkelso/natural-earth-vector/v5.1.2/geojson/{layer}.geojson'
    data = json.load(urlopen(url))
    for feature in data['features']:
        props, geometry = feature['properties'], feature['geometry']
        name = props.get('NAME_EN') or props.get('name_en') or props.get('NAME') or props.get('name')
        if not isinstance(name, str) or not name.strip():
            continue
        code = next((props.get(key) for key in ['ISO_A2_EH', 'ISO_A2']
                     if isinstance(props.get(key), str) and len(props[key]) == 2 and props[key].isascii() and props[key].isalpha()), None)
        names = {lang: value.strip() for lang in languages
                 if isinstance(value := props.get('NAME_' + lang.upper()) or props.get('name_' + lang), str) and value.strip()}
        names.setdefault('en', name)
        place_id = f"{kind}-{props.get('NE_ID') or props['ne_id']}"
        places[place_id] = dict(names=names, countryCode=code if kind == 'land' else None)
        polygons = geometry['coordinates'] if geometry['type'] == 'MultiPolygon' else [geometry['coordinates']]
        for polygon in polygons:
            rings = [[[round(x, 4), round(y, 4)] for x, y in ring] for ring in polygon]
            xs, ys = zip(*rings[0])
            regions.append(dict(placeID=place_id, kind=kind, bounds=[min(xs), min(ys), max(xs), max(ys)], rings=rings))
path = root / 'Frameworks/SatelliteForecast/Impl/Sources/Resources/Geography/regions.json'
path.write_text(json.dumps(dict(places=places, regions=regions, subdivisionCountries=subdivision_countries), separators=(',', ':'), ensure_ascii=False) + '\n')
print(f'{len(regions)} polygons; {len(places)} place records; {path.stat().st_size:,} bytes')
for lang in languages:
    print(f'{lang}: {sum(lang in p["names"] for p in places.values())}/{len(places)} translated names')

# Keep region detail separate: ocean lookups need not load subdivision geometry.
layer = 'ne_10m_admin_1_states_provinces'
data = json.load(urlopen(f'https://raw.githubusercontent.com/nvkelso/natural-earth-vector/v5.1.2/geojson/{layer}.geojson'))
regions, places = [], {}
for feature in data['features']:
    props, geometry = feature['properties'], feature['geometry']
    code = props.get('iso_a2')
    if code not in subdivision_countries:
        continue
    name = props.get('name_en') or props.get('name')
    if not isinstance(name, str) or not name.strip():
        continue
    names = {lang: value.strip() for lang in languages
             if isinstance(value := props.get('name_' + lang), str) and value.strip()}
    names.setdefault('en', name)
    place_id = 'subdivision-' + str(props['ne_id'])
    places[place_id] = dict(names=names, countryCode=code)
    polygons = geometry['coordinates'] if geometry['type'] == 'MultiPolygon' else [geometry['coordinates']]
    for polygon in polygons:
        rings = [[[round(x, 4), round(y, 4)] for x, y in ring] for ring in polygon]
        xs, ys = zip(*rings[0])
        regions.append(dict(placeID=place_id, kind='subdivision', bounds=[min(xs), min(ys), max(xs), max(ys)], rings=rings))
path = path.with_name('subdivisions.json')
path.write_text(json.dumps(dict(places=places, regions=regions), separators=(',', ':'), ensure_ascii=False) + '\n')
print(f'Subdivisions: {len(places)} regions in {len(subdivision_countries)} countries; {path.stat().st_size:,} bytes')
