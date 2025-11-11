#!/usr/bin/env python3
"""
Test script to simulate zip code input and see what might be causing crashes
"""
import requests

# Test the geocoding API with a zip code directly
def test_zip_code():
    zip_code = "10001"  # New York zip code
    
    params = {
        "q": zip_code,
        "format": "json",
        "addressdetails": 1,
        "limit": 5,
    }
    headers = {
        "User-Agent": "FastWeather GUI/1.0 (accessible weather app)"
    }
    
    try:
        print(f"Testing zip code: {zip_code}")
        response = requests.get("https://nominatim.openstreetmap.org/search", 
                               params=params, headers=headers, timeout=10)
        response.raise_for_status()
        results = response.json()
        
        print(f"Got {len(results)} results:")
        
        for i, r in enumerate(results):
            print(f"\nResult {i+1}:")
            print(f"  Display name: {r.get('display_name', 'N/A')}")
            print(f"  Lat: {r.get('lat', 'N/A')}")
            print(f"  Lon: {r.get('lon', 'N/A')}")
            
            address = r.get("address", {})
            city_name = address.get('city') or address.get('town') or address.get('village') or zip_code
            state = address.get('state', '')
            country = address.get('country', '')
            
            print(f"  Parsed city: {city_name}")
            print(f"  State: {state}")
            print(f"  Country: {country}")
            
            # Build display name like the app does
            display_parts = [city_name]
            if state:
                display_parts.append(state)
            if country:
                display_parts.append(country)
            
            final_display = ", ".join(display_parts)
            print(f"  Final display: {final_display}")
        
        print("\nTest completed successfully!")
        
    except Exception as e:
        print(f"Error occurred: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    test_zip_code()
