#!/usr/bin/env python3
"""
Safety check for distribute-caches scripts.
Verifies CityData/us-cities-cached.json has >= cities as each destination.
Exit code 1 if source is behind any destination.
"""
import json
import os
import sys

def count(path):
    try:
        data = json.load(open(path, encoding='utf-8'))
        return sum(len(v) for v in data.values())
    except Exception:
        return None

src_count = count('us-cities-cached.json')
if src_count is None:
    print('ERROR: Could not read us-cities-cached.json')
    sys.exit(1)

dests = [
    ('../us-cities-cached.json', 'root'),
    ('../FastWeatherMac/us-cities-cached.json', 'FastWeatherMac'),
    ('../iOS/FastWeather/Resources/us-cities-cached.json', 'iOS'),
    ('../webapp/us-cities-cached.json', 'webapp'),
]

error = False
for path, name in dests:
    if os.path.exists(path):
        dst_count = count(path)
        if dst_count is not None and src_count < dst_count:
            print(f'  ERROR: Source has {src_count} US cities but {name} has {dst_count}.')
            print(f'  Fix: copy ..\\us-cities-cached.json . (Windows) or cp ../us-cities-cached.json . (bash)')
            error = True

if error:
    sys.exit(1)
print(f'  OK: source has {src_count} US cities — safe to distribute.')
