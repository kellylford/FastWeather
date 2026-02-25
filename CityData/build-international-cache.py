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
from country_names import normalize_country, get_unmapped_warning

# Country name to ISO 3166-1 alpha-2 code mapping
COUNTRY_CODES = {
    'Algeria': 'dz',
    'Angola': 'ao',
    'Argentina': 'ar',
    'Armenia': 'am',
    'Australia': 'au',
    'Austria': 'at',
    'Azerbaijan': 'az',
    'Bahrain': 'bh',
    'Bangladesh': 'bd',
    'Belgium': 'be',
    'Bolivia': 'bo',
    'Brazil': 'br',
    'Bulgaria': 'bg',
    'Cambodia': 'kh',
    'Cameroon': 'cm',
    'Canada': 'ca',
    'Chile': 'cl',
    'China': 'cn',
    'Colombia': 'co',
    'Costa Rica': 'cr',
    'Croatia': 'hr',
    'Cuba': 'cu',
    'Czech Republic': 'cz',
    'Côte d\'Ivoire': 'ci',
    'Denmark': 'dk',
    'Dominican Republic': 'do',
    'Ecuador': 'ec',
    'Egypt': 'eg',
    'El Salvador': 'sv',
    'Ethiopia': 'et',
    'Finland': 'fi',
    'France': 'fr',
    'Georgia': 'ge',
    'Germany': 'de',
    'Ghana': 'gh',
    'Greece': 'gr',
    'Greenland': 'gl',
    'Guatemala': 'gt',
    'Honduras': 'hn',
    'Hungary': 'hu',
    'India': 'in',
    'Indonesia': 'id',
    'Iran': 'ir',
    'Iraq': 'iq',
    'Ireland': 'ie',
    'Israel': 'il',
    'Italy': 'it',
    'Jamaica': 'jm',
    'Japan': 'jp',
    'Jordan': 'jo',
    'Kazakhstan': 'kz',
    'Kenya': 'ke',
    'Kuwait': 'kw',
    'Laos': 'la',
    'Lebanon': 'lb',
    'Malaysia': 'my',
    'Mexico': 'mx',
    'Morocco': 'ma',
    'Mozambique': 'mz',
    'Myanmar': 'mm',
    'Netherlands': 'nl',
    'New Zealand': 'nz',
    'Nigeria': 'ng',
    'Norway': 'no',
    'Oman': 'om',
    'Pakistan': 'pk',
    'Panama': 'pa',
    'Paraguay': 'py',
    'Peru': 'pe',
    'Philippines': 'ph',
    'Poland': 'pl',
    'Portugal': 'pt',
    'Qatar': 'qa',
    'Romania': 'ro',
    'Russia': 'ru',
    'Saudi Arabia': 'sa',
    'Senegal': 'sn',
    'Serbia': 'rs',
    'Singapore': 'sg',
    'Slovakia': 'sk',
    'Slovenia': 'si',
    'South Africa': 'za',
    'South Korea': 'kr',
    'Spain': 'es',
    'Sweden': 'se',
    'Switzerland': 'ch',
    'Taiwan': 'tw',
    'Tanzania': 'tz',
    'Thailand': 'th',
    'Trinidad and Tobago': 'tt',
    'Tunisia': 'tn',
    'Turkey': 'tr',
    'Uganda': 'ug',
    'Ukraine': 'ua',
    'United Arab Emirates': 'ae',
    'United Kingdom': 'gb',
    'Uruguay': 'uy',
    'Uzbekistan': 'uz',
    'Venezuela': 've',
    'Vietnam': 'vn',
    'Zimbabwe': 'zw'
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
            
            # Get country code and normalize to English
            country_code_iso = address.get('country_code', '').upper()
            native_country = address.get('country', country_name)
            
            # Normalize country name to English
            normalized_country = normalize_country(native_country, country_code_iso)
            
            # Log the mapping for verification
            if normalized_country != native_country:
                print(f"  Mapped {country_code_iso} '{native_country}' → '{normalized_country}'")
            elif country_code_iso and country_code_iso not in ['US', 'GB', 'CA', 'AU']:
                # Warn about unmapped codes (exclude common English-speaking countries)
                print(f"  {get_unmapped_warning(native_country, country_code_iso)}")
            
            # Get state/province/region if available
            state = (address.get('state') or 
                    address.get('province') or 
                    address.get('region') or 
                    '')
            
            return {
                'name': city_name,
                'state': state,
                'country': normalized_country,
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
    
    # Auto-start for background execution
    # input("\nPress Enter to start...")
    print("\nStarting cache rebuild...")
    main()
