#!/usr/bin/env python3
"""
Add Northern Ireland cities to the international cities cache.
Queries Nominatim as "CityName, Northern Ireland" to avoid ambiguity
(e.g. Bangor, Northern Ireland vs Bangor, Wales).
State field is set to the bilingual standard used by existing Belfast entry.
Derry is geocoded as "Derry" then renamed to "Derry/Londonderry".
Safely restartable — skips cities already in the cache.
Estimated runtime: ~25 seconds (20 cities at 1.1 sec each).
"""

import json
import time
import subprocess
import requests
from pathlib import Path

NI_STATE = 'Northern Ireland / Tuaisceart Éireann'

# Geocode as "Name, Northern Ireland" to avoid disambiguation issues.
# display_name overrides the stored name where it differs from the query name.
NI_CITIES = [
    {'query': 'Derry',          'display_name': 'Derry/Londonderry'},
    {'query': 'Lisburn'},
    {'query': 'Newtownabbey'},
    {'query': 'Bangor'},        # County Down — query scoped to Northern Ireland
    {'query': 'Newry'},
    {'query': 'Armagh'},
    {'query': 'Ballymena'},
    {'query': 'Antrim'},
    {'query': 'Carrickfergus'},
    {'query': 'Coleraine'},
    {'query': 'Lurgan'},
    {'query': 'Portadown'},
    {'query': 'Omagh'},
    {'query': 'Enniskillen'},
    {'query': 'Craigavon'},
    {'query': 'Dungannon'},
    {'query': 'Strabane'},
    {'query': 'Larne'},
    {'query': 'Downpatrick'},
    {'query': 'Ballymoney'},
]


def geocode_ni_city(query_name):
    url = 'https://nominatim.openstreetmap.org/search'
    params = {
        'q': f'{query_name}, Northern Ireland',
        'format': 'json',
        'addressdetails': '1',
        'limit': 1,
        'countrycodes': 'gb',
    }
    headers = {'User-Agent': 'FastWeather NI-Expand/1.0'}
    try:
        r = requests.get(url, params=params, headers=headers, timeout=10)
        r.raise_for_status()
        results = r.json()
        if results:
            result = results[0]
            return {
                'lat': float(result['lat']),
                'lon': float(result['lon']),
            }
    except Exception as e:
        print(f'    Error: {e}')
    return None


def main():
    cache_file = Path('international-cities-cached.json')

    with open(cache_file, 'r', encoding='utf-8') as f:
        cache = json.load(f)

    uk_cities = cache.get('United Kingdom', [])
    existing_names = {c['name'].lower() for c in uk_cities}

    to_add = [c for c in NI_CITIES if c.get('display_name', c['query']).lower() not in existing_names]

    if not to_add:
        print('All Northern Ireland cities are already in the cache.')
        return

    print('='*60)
    print('FastWeather — Northern Ireland City Expander')
    print(f'Adding {len(to_add)} cities to United Kingdom')
    print('Safely restartable — skips already-cached cities')
    print('='*60)

    for i, city in enumerate(to_add, 1):
        query = city['query']
        name = city.get('display_name', query)
        print(f'  [{i}/{len(to_add)}] {name} (searching "{query}, Northern Ireland")... ', end='', flush=True)

        coords = geocode_ni_city(query)
        if coords:
            uk_cities.append({
                'name': name,
                'state': NI_STATE,
                'country': 'United Kingdom',
                'lat': coords['lat'],
                'lon': coords['lon'],
            })
            print(f'✓  ({coords["lat"]:.4f}, {coords["lon"]:.4f})')
        else:
            print('✗ failed — skipping')

        if i < len(to_add):
            time.sleep(1.1)

    cache['United Kingdom'] = uk_cities

    with open(cache_file, 'w', encoding='utf-8') as f:
        json.dump(cache, f, indent=2, ensure_ascii=False)

    ni_count = sum(1 for c in uk_cities if c.get('state') == NI_STATE)
    print(f'\n✅ Done. United Kingdom now has {len(uk_cities)} cities ({ni_count} in Northern Ireland).')

    # Distribute to all platforms
    print('\nDistributing to all platforms...')
    result = subprocess.run(['bash', 'distribute-caches.sh'], capture_output=True, text=True)
    if result.returncode == 0:
        print('✅ Distribution complete!')
    else:
        dist_result = subprocess.run(['distribute-caches.bat'], capture_output=True, text=True, shell=True)
        if dist_result.returncode == 0:
            print('✅ Distribution complete!')
        else:
            print('⚠️  Auto-distribution failed. Run distribute-caches.bat manually.')
            print(result.stderr)


if __name__ == '__main__':
    main()
