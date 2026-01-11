#!/usr/bin/env python3
"""
Background task to geocode international cities and build cached coordinates file.
Run this once to populate international-cities-cached.json with all country data.
"""

import json
import time
import requests
import re
from pathlib import Path

# Country name to ISO 3166-1 alpha-2 code mapping
COUNTRY_CODES = {
    'Argentina': 'ar',
    'Australia': 'au',
    'Austria': 'at',
    'Bangladesh': 'bd',
    'Belgium': 'be',
    'Brazil': 'br',
    'Canada': 'ca',
    'China': 'cn',
    'Denmark': 'dk',
    'Egypt': 'eg',
    'Ethiopia': 'et',
    'Finland': 'fi',
    'France': 'fr',
    'Germany': 'de',
    'India': 'in',
    'Indonesia': 'id',
    'Iran': 'ir',
    'Iraq': 'iq',
    'Ireland': 'ie',
    'Israel': 'il',
    'Italy': 'it',
    'Japan': 'jp',
    'Jordan': 'jo',
    'Kenya': 'ke',
    'Kuwait': 'kw',
    'Malaysia': 'my',
    'Mexico': 'mx',
    'Morocco': 'ma',
    'Netherlands': 'nl',
    'New Zealand': 'nz',
    'Nigeria': 'ng',
    'Norway': 'no',
    'Pakistan': 'pk',
    'Philippines': 'ph',
    'Poland': 'pl',
    'Qatar': 'qa',
    'Russia': 'ru',
    'Saudi Arabia': 'sa',
    'Singapore': 'sg',
    'South Africa': 'za',
    'South Korea': 'kr',
    'Spain': 'es',
    'Sweden': 'se',
    'Switzerland': 'ch',
    'Taiwan': 'tw',
    'Thailand': 'th',
    'Turkey': 'tr',
    'Ukraine': 'ua',
    'United Arab Emirates': 'ae',
    'United Kingdom': 'gb',
    'Vietnam': 'vn'
}

# Load the city names from JavaScript file
with open('international-cities-data.js', 'r', encoding='utf-8') as f:
    content = f.read()

# Extract country names and city arrays using regex
INTERNATIONAL_CITIES_BY_COUNTRY = {}
country_pattern = r'"([^"]+)":\s*\[(.*?)\]'
matches = re.finditer(country_pattern, content, re.DOTALL)

for match in matches:
    country_name = match.group(1)
    cities_str = match.group(2)
    # Extract city names from quoted strings
    city_names = re.findall(r'"([^"]+)"', cities_str)
    if city_names:
        INTERNATIONAL_CITIES_BY_COUNTRY[country_name] = city_names

print(f"Loaded {len(INTERNATIONAL_CITIES_BY_COUNTRY)} countries with city data")
for country, cities in INTERNATIONAL_CITIES_BY_COUNTRY.items():
    print(f"  {country}: {len(cities)} cities")

def geocode_city(city_name, country_name, country_code):
    """Geocode a city using Nominatim API"""
    url = 'https://nominatim.openstreetmap.org/search'
    params = {
        'q': f'{city_name}, {country_name}',
        'format': 'json',
        'addressdetails': '1',
        'countrycodes': country_code,
        'limit': 1
    }
    headers = {
        'User-Agent': 'FastWeather International CacheBuilder/1.0'
    }
    
    try:
        response = requests.get(url, params=params, headers=headers, timeout=10)
        response.raise_for_status()
        results = response.json()
        
        if results and len(results) > 0:
            result = results[0]
            address = result.get('address', {})
            
            # Get the most appropriate country name from the result
            result_country = address.get('country', country_name)
            
            # Get state/province/region if available
            state = (address.get('state') or 
                    address.get('province') or 
                    address.get('region') or 
                    '')
            
            return {
                'name': city_name,
                'state': state,
                'country': result_country,
                'lat': float(result['lat']),
                'lon': float(result['lon'])
            }
    except Exception as e:
        print(f"Error geocoding {city_name}, {country_name}: {e}")
    
    return None

def main():
    output_file = Path('international-cities-cached.json')
    
    # Load existing cache if it exists
    if output_file.exists():
        with open(output_file, 'r', encoding='utf-8') as f:
            cached_data = json.load(f)
        print(f"\nLoaded existing cache with {len(cached_data)} countries")
    else:
        cached_data = {}
    
    total_countries = len(INTERNATIONAL_CITIES_BY_COUNTRY)
    processed = 0
    
    for country_name, city_names in INTERNATIONAL_CITIES_BY_COUNTRY.items():
        processed += 1
        country_code = COUNTRY_CODES.get(country_name, '')
        
        # Skip if already cached
        if country_name in cached_data and len(cached_data[country_name]) >= len(city_names):
            print(f"\n[{processed}/{total_countries}] Skipping {country_name} (already cached with {len(cached_data[country_name])} cities)")
            continue
        
        print(f"\n[{processed}/{total_countries}] Processing {country_name} ({country_code})...")
        country_cities = []
        
        for i, city_name in enumerate(city_names, 1):
            print(f"  [{i}/{len(city_names)}] Geocoding {city_name}...", end=' ')
            
            city_data = geocode_city(city_name, country_name, country_code)
            if city_data:
                country_cities.append(city_data)
                print("✓")
            else:
                print("✗ Failed")
            
            # Rate limiting: 1 request per second (Nominatim requirement)
            if i < len(city_names):
                time.sleep(1.1)
        
        # Save progress after each country
        cached_data[country_name] = country_cities
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(cached_data, f, indent=2, ensure_ascii=False)
        
        print(f"  ✓ Saved {len(country_cities)} cities for {country_name}")
        
        # Extra delay between countries to be respectful to the API
        if processed < total_countries:
            print("  Waiting 5 seconds before next country...")
            time.sleep(5)
    
    print(f"\n{'='*60}")
    print(f"✅ Complete! Cached {sum(len(v) for v in cached_data.values())} cities across {len(cached_data)} countries")
    print(f"Output saved to: {output_file}")
    print(f"{'='*60}")
    
    # Summary
    print("\nSummary by country:")
    for country in sorted(cached_data.keys()):
        print(f"  {country}: {len(cached_data[country])} cities")

if __name__ == '__main__':
    print("="*60)
    print("FastWeather International Cities Cache Builder")
    print("="*60)
    print("\nThis script will geocode cities from international-cities-data.js")
    print("and create a cached coordinates file for fast loading.")
    print("\nEstimated time: ~40-50 minutes (25 countries × ~20 cities × 1.1 sec/city)")
    print("\nNOTE: The script respects Nominatim's rate limit of 1 request/second")
    print("and saves progress after each country in case of interruption.")
    print("="*60)
    
    input("\nPress Enter to start...")
    main()
