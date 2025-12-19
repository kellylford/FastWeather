#!/usr/bin/env python3
"""
Background task to geocode all US cities and build cached coordinates file.
Run this once to populate us-cities-cached.json with all state data.
"""

import json
import time
import requests
import re
from pathlib import Path

# Load the city names from JavaScript file
with open('us-cities-data.js', 'r', encoding='utf-8') as f:
    content = f.read()

# Extract state names and city arrays using regex
US_CITIES_BY_STATE = {}
state_pattern = r'"([^"]+)":\s*\[(.*?)\]'
matches = re.finditer(state_pattern, content, re.DOTALL)

for match in matches:
    state_name = match.group(1)
    cities_str = match.group(2)
    # Extract city names from quoted strings
    city_names = re.findall(r'"([^"]+)"', cities_str)
    if city_names:
        US_CITIES_BY_STATE[state_name] = city_names

print(f"Loaded {len(US_CITIES_BY_STATE)} states with city data")

def geocode_city(city_name, state_name):
    """Geocode a city using Nominatim API"""
    url = 'https://nominatim.openstreetmap.org/search'
    params = {
        'q': f'{city_name}, {state_name}',
        'format': 'json',
        'addressdetails': '1',
        'countrycodes': 'us',
        'limit': 1
    }
    headers = {
        'User-Agent': 'FastWeather CacheBuilder/1.0'
    }
    
    try:
        response = requests.get(url, params=params, headers=headers, timeout=10)
        response.raise_for_status()
        results = response.json()
        
        if results and len(results) > 0:
            result = results[0]
            address = result.get('address', {})
            return {
                'name': city_name,
                'state': address.get('state', state_name),
                'country': address.get('country', 'United States'),
                'lat': float(result['lat']),
                'lon': float(result['lon'])
            }
    except Exception as e:
        print(f"Error geocoding {city_name}, {state_name}: {e}")
    
    return None

def main():
    output_file = Path('us-cities-cached.json')
    
    # Load existing cache if it exists
    if output_file.exists():
        with open(output_file, 'r', encoding='utf-8') as f:
            cached_data = json.load(f)
        print(f"Loaded existing cache with {len(cached_data)} states")
    else:
        cached_data = {}
    
    total_states = len(US_CITIES_BY_STATE)
    processed = 0
    
    for state_name, city_names in US_CITIES_BY_STATE.items():
        processed += 1
        
        # Skip if already cached
        if state_name in cached_data and len(cached_data[state_name]) >= len(city_names):
            print(f"[{processed}/{total_states}] Skipping {state_name} (already cached)")
            continue
        
        print(f"\n[{processed}/{total_states}] Processing {state_name}...")
        state_cities = []
        
        for i, city_name in enumerate(city_names, 1):
            print(f"  [{i}/{len(city_names)}] Geocoding {city_name}...", end=' ')
            
            city_data = geocode_city(city_name, state_name)
            if city_data:
                state_cities.append(city_data)
                print("✓")
            else:
                print("✗ Failed")
            
            # Rate limiting: 1 request per second
            if i < len(city_names):
                time.sleep(1.1)
        
        # Save progress after each state
        cached_data[state_name] = state_cities
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(cached_data, f, indent=2, ensure_ascii=False)
        
        print(f"  Saved {len(state_cities)} cities for {state_name}")
    
    print(f"\n✅ Complete! Cached {sum(len(v) for v in cached_data.values())} cities across {len(cached_data)} states")
    print(f"Output saved to: {output_file}")

if __name__ == '__main__':
    main()
