#!/usr/bin/env python3
"""
Script to add more countries to the international cities database.
This adds ~93 additional countries beyond the current 101.
"""

import json
import time
import requests
from pathlib import Path

# Additional countries with major cities to add
NEW_COUNTRIES_WITH_CITIES = {
    'Afghanistan': ['Kabul', 'Kandahar', 'Herat', 'Mazar-i-Sharif', 'Jalalabad'],
    'Albania': ['Tirana', 'Durrës', 'Vlorë', 'Elbasan', 'Shkodër'],
    'Bahamas': ['Nassau', 'Freeport', 'West End', 'Coopers Town', 'Marsh Harbour'],
    'Barbados': ['Bridgetown', 'Speightstown', 'Oistins', 'Holetown', 'Bathsheba'],
    'Belarus': ['Minsk', 'Gomel', 'Mogilev', 'Vitebsk', 'Grodno', 'Brest'],
    'Belize': ['Belize City', 'San Ignacio', 'Orange Walk', 'Belmopan', 'Dangriga'],
    'Benin': ['Cotonou', 'Porto-Novo', 'Parakou', 'Djougou', 'Bohicon'],
    'Bermuda': ['Hamilton', 'St. George', 'Somerset', 'Flatts Village', 'Tucker\'s Town'],
    'Bhutan': ['Thimphu', 'Paro', 'Punakha', 'Phuentsholing', 'Jakar'],
    'Bosnia and Herzegovina': ['Sarajevo', 'Banja Luka', 'Tuzla', 'Zenica', 'Mostar'],
    'Botswana': ['Gaborone', 'Francistown', 'Maun', 'Kasane', 'Serowe'],
    'Brunei': ['Bandar Seri Begawan', 'Kuala Belait', 'Seria', 'Tutong', 'Bangar'],
    'Burkina Faso': ['Ouagadougou', 'Bobo-Dioulasso', 'Koudougou', 'Ouahigouya', 'Banfora'],
    'Burundi': ['Gitega', 'Bujumbura', 'Muyinga', 'Ngozi', 'Rumonge'],
    'Cape Verde': ['Praia', 'Mindelo', 'Santa Maria', 'Assomada', 'Porto Novo'],
    'Central African Republic': ['Bangui', 'Bimbo', 'Berbérati', 'Carnot', 'Bambari'],
    'Chad': ['N\'Djamena', 'Moundou', 'Sarh', 'Abéché', 'Kélo'],
    'Comoros': ['Moroni', 'Mutsamudu', 'Fomboni', 'Domoni', 'Tsimbeo'],
    'Congo': ['Brazzaville', 'Pointe-Noire', 'Dolisie', 'Nkayi', 'Owando'],
    'Cyprus': ['Nicosia', 'Limassol', 'Larnaca', 'Paphos', 'Famagusta'],
    'Djibouti': ['Djibouti City', 'Ali Sabieh', 'Tadjourah', 'Obock', 'Dikhil'],
    'Dominica': ['Roseau', 'Portsmouth', 'Marigot', 'Berekua', 'Saint Joseph'],
    'East Timor': ['Dili', 'Baucau', 'Maliana', 'Suai', 'Liquiçá'],
    'Equatorial Guinea': ['Malabo', 'Bata', 'Ebebiyin', 'Aconibe', 'Añisoc'],
    'Eritrea': ['Asmara', 'Keren', 'Massawa', 'Assab', 'Mendefera'],
    'Estonia': ['Tallinn', 'Tartu', 'Narva', 'Pärnu', 'Kohtla-Järve'],
    'Eswatini': ['Mbabane', 'Manzini', 'Lobamba', 'Siteki', 'Malkerns'],
    'Fiji': ['Suva', 'Nadi', 'Lautoka', 'Labasa', 'Ba'],
    'Gabon': ['Libreville', 'Port-Gentil', 'Franceville', 'Oyem', 'Moanda'],
    'Gambia': ['Banjul', 'Serekunda', 'Brikama', 'Bakau', 'Farafenni'],
    'Grenada': ['St. George\'s', 'Gouyave', 'Grenville', 'Victoria', 'Sauteurs'],
    'Guinea': ['Conakry', 'Nzérékoré', 'Kankan', 'Kindia', 'Labé'],
    'Guinea-Bissau': ['Bissau', 'Bafatá', 'Gabú', 'Bissorã', 'Bolama'],
    'Guyana': ['Georgetown', 'Linden', 'New Amsterdam', 'Anna Regina', 'Bartica'],
    'Haiti': ['Port-au-Prince', 'Cap-Haïtien', 'Gonaïves', 'Les Cayes', 'Port-de-Paix'],
    'Hong Kong': ['Hong Kong', 'Kowloon', 'Tsuen Wan', 'Sha Tin', 'Tuen Mun'],
    'Iceland': ['Reykjavik', 'Akureyri', 'Keflavik', 'Hafnarfjörður', 'Selfoss'],
    'Kosovo': ['Pristina', 'Prizren', 'Gjakova', 'Peja', 'Mitrovica'],
    'Kyrgyzstan': ['Bishkek', 'Osh', 'Jalal-Abad', 'Karakol', 'Tokmok'],
    'Latvia': ['Riga', 'Daugavpils', 'Liepāja', 'Jelgava', 'Jūrmala'],
    'Lesotho': ['Maseru', 'Teyateyaneng', 'Mafeteng', 'Hlotse', 'Mohale\'s Hoek'],
    'Liberia': ['Monrovia', 'Gbarnga', 'Buchanan', 'Ganta', 'Kakata'],
    'Libya': ['Tripoli', 'Benghazi', 'Misrata', 'Bayda', 'Zawiya'],
    'Liechtenstein': ['Vaduz', 'Schaan', 'Balzers', 'Triesen', 'Eschen'],
    'Lithuania': ['Vilnius', 'Kaunas', 'Klaipėda', 'Šiauliai', 'Panevėžys'],
    'Luxembourg': ['Luxembourg City', 'Esch-sur-Alzette', 'Differdange', 'Dudelange', 'Ettelbruck'],
    'Macau': ['Macau', 'Taipa', 'Coloane', 'Cotai'],
    'Madagascar': ['Antananarivo', 'Toamasina', 'Antsirabe', 'Fianarantsoa', 'Mahajanga'],
    'Malawi': ['Lilongwe', 'Blantyre', 'Mzuzu', 'Zomba', 'Kasungu'],
    'Maldives': ['Malé', 'Addu City', 'Fuvahmulah', 'Kulhudhuffushi', 'Thinadhoo'],
    'Mali': ['Bamako', 'Sikasso', 'Mopti', 'Koutiala', 'Kayes'],
    'Malta': ['Valletta', 'Birkirkara', 'Mosta', 'Qormi', 'Sliema'],
    'Mauritania': ['Nouakchott', 'Nouadhibou', 'Néma', 'Kaédi', 'Rosso'],
    'Mauritius': ['Port Louis', 'Curepipe', 'Vacoas-Phoenix', 'Quatre Bornes', 'Triolet'],
    'Moldova': ['Chișinău', 'Tiraspol', 'Bălți', 'Bender', 'Rîbnița'],
    'Monaco': ['Monte Carlo', 'Monaco-Ville', 'La Condamine', 'Fontvieille'],
    'Mongolia': ['Ulaanbaatar', 'Erdenet', 'Darkhan', 'Choibalsan', 'Khovd'],
    'Montenegro': ['Podgorica', 'Nikšić', 'Pljevlja', 'Bijelo Polje', 'Herceg Novi'],
    'Namibia': ['Windhoek', 'Walvis Bay', 'Swakopmund', 'Rundu', 'Oshakati'],
    'Nepal': ['Kathmandu', 'Pokhara', 'Lalitpur', 'Biratnagar', 'Bharatpur'],
    'Nicaragua': ['Managua', 'León', 'Granada', 'Masaya', 'Matagalpa'],
    'Niger': ['Niamey', 'Zinder', 'Maradi', 'Agadez', 'Tahoua'],
    'North Macedonia': ['Skopje', 'Bitola', 'Kumanovo', 'Prilep', 'Tetovo'],
    'Papua New Guinea': ['Port Moresby', 'Lae', 'Mount Hagen', 'Madang', 'Wewak'],
    'Puerto Rico': ['San Juan', 'Bayamón', 'Carolina', 'Ponce', 'Caguas'],
    'Rwanda': ['Kigali', 'Butare', 'Gitarama', 'Ruhengeri', 'Gisenyi'],
    'San Marino': ['San Marino', 'Serravalle', 'Borgo Maggiore', 'Domagnano', 'Fiorentino'],
    'Sierra Leone': ['Freetown', 'Bo', 'Kenema', 'Makeni', 'Koidu'],
    'Somalia': ['Mogadishu', 'Hargeisa', 'Bosaso', 'Kismayo', 'Merca'],
    'South Sudan': ['Juba', 'Wau', 'Malakal', 'Yei', 'Yambio'],
    'Sri Lanka': ['Colombo', 'Kandy', 'Galle', 'Jaffna', 'Negombo'],
    'Sudan': ['Khartoum', 'Omdurman', 'Port Sudan', 'Kassala', 'Nyala'],
    'Suriname': ['Paramaribo', 'Lelydorp', 'Nieuw Nickerie', 'Moengo', 'Albina'],
    'Syria': ['Damascus', 'Aleppo', 'Homs', 'Latakia', 'Hama'],
    'Tajikistan': ['Dushanbe', 'Khujand', 'Kulob', 'Qurghonteppa', 'Istaravshan'],
    'Togo': ['Lomé', 'Sokodé', 'Kara', 'Atakpamé', 'Kpalimé'],
    'Turkmenistan': ['Ashgabat', 'Türkmenabat', 'Daşoguz', 'Mary', 'Balkanabat'],
    'United States': ['New York', 'Los Angeles', 'Chicago', 'Houston', 'Phoenix'],
    'Vanuatu': ['Port Vila', 'Luganville', 'Norsup', 'Isangel', 'Sola'],
    'Yemen': ['Sana\'a', 'Aden', 'Taiz', 'Hodeidah', 'Ibb'],
    'Zambia': ['Lusaka', 'Kitwe', 'Ndola', 'Kabwe', 'Chingola'],
}

# Country codes
COUNTRY_CODES = {
    'Afghanistan': 'af', 'Albania': 'al', 'Bahamas': 'bs', 'Barbados': 'bb',
    'Belarus': 'by', 'Belize': 'bz', 'Benin': 'bj', 'Bermuda': 'bm',
    'Bhutan': 'bt', 'Bosnia and Herzegovina': 'ba', 'Botswana': 'bw', 'Brunei': 'bn',
    'Burkina Faso': 'bf', 'Burundi': 'bi', 'Cape Verde': 'cv', 'Central African Republic': 'cf',
    'Chad': 'td', 'Comoros': 'km', 'Congo': 'cg', 'Cyprus': 'cy',
    'Djibouti': 'dj', 'Dominica': 'dm', 'East Timor': 'tl', 'Equatorial Guinea': 'gq',
    'Eritrea': 'er', 'Estonia': 'ee', 'Eswatini': 'sz', 'Fiji': 'fj',
    'Gabon': 'ga', 'Gambia': 'gm', 'Grenada': 'gd', 'Guinea': 'gn',
    'Guinea-Bissau': 'gw', 'Guyana': 'gy', 'Haiti': 'ht', 'Hong Kong': 'hk',
    'Iceland': 'is', 'Kosovo': 'xk', 'Kyrgyzstan': 'kg', 'Latvia': 'lv',
    'Lesotho': 'ls', 'Liberia': 'lr', 'Libya': 'ly', 'Liechtenstein': 'li',
    'Lithuania': 'lt', 'Luxembourg': 'lu', 'Macau': 'mo', 'Madagascar': 'mg',
    'Malawi': 'mw', 'Maldives': 'mv', 'Mali': 'ml', 'Malta': 'mt',
    'Mauritania': 'mr', 'Mauritius': 'mu', 'Moldova': 'md', 'Monaco': 'mc',
    'Mongolia': 'mn', 'Montenegro': 'me', 'Namibia': 'na', 'Nepal': 'np',
    'Nicaragua': 'ni', 'Niger': 'ne', 'North Macedonia': 'mk', 'Papua New Guinea': 'pg',
    'Puerto Rico': 'pr', 'Rwanda': 'rw', 'San Marino': 'sm', 'Sierra Leone': 'sl',
    'Somalia': 'so', 'South Sudan': 'ss', 'Sri Lanka': 'lk', 'Sudan': 'sd',
    'Suriname': 'sr', 'Syria': 'sy', 'Tajikistan': 'tj', 'Togo': 'tg',
    'Turkmenistan': 'tm', 'United States': 'us', 'Vanuatu': 'vu', 'Yemen': 'ye',
    'Zambia': 'zm',
}

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
        'User-Agent': 'FastWeather International CacheBuilder/2.0'
    }
    
    try:
        response = requests.get(url, params=params, headers=headers, timeout=10)
        response.raise_for_status()
        results = response.json()
        
        if results and len(results) > 0:
            result = results[0]
            address = result.get('address', {})
            
            result_country = address.get('country', country_name)
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
    
    # Load existing cache
    if output_file.exists():
        with open(output_file, 'r', encoding='utf-8') as f:
            cached_data = json.load(f)
        print(f"Loaded existing cache with {len(cached_data)} countries")
    else:
        cached_data = {}
    
    total_countries = len(NEW_COUNTRIES_WITH_CITIES)
    processed = 0
    total_cities_added = 0
    
    for country_name, city_names in NEW_COUNTRIES_WITH_CITIES.items():
        processed += 1
        country_code = COUNTRY_CODES.get(country_name, '')
        
        # Skip if already cached
        if country_name in cached_data:
            print(f"[{processed}/{total_countries}] Skipping {country_name} (already cached)")
            continue
        
        print(f"\n[{processed}/{total_countries}] Processing {country_name} ({country_code})...")
        country_cities = []
        
        for i, city_name in enumerate(city_names, 1):
            print(f"  [{i}/{len(city_names)}] {city_name}...", end=' ', flush=True)
            
            city_data = geocode_city(city_name, country_name, country_code)
            if city_data:
                country_cities.append(city_data)
                print("✓")
            else:
                print("✗")
            
            # Rate limiting: 1 request per second
            if i < len(city_names):
                time.sleep(1.1)
        
        # Save progress
        if country_cities:
            cached_data[country_name] = country_cities
            total_cities_added += len(country_cities)
            with open(output_file, 'w', encoding='utf-8') as f:
                json.dump(cached_data, f, indent=2, ensure_ascii=False)
            print(f"  ✓ Saved {len(country_cities)} cities")
        
        # Delay between countries
        if processed < total_countries:
            time.sleep(2)
    
    print(f"\n{'='*60}")
    print(f"✅ Added {total_cities_added} cities across {processed} new countries")
    print(f"Total: {sum(len(v) for v in cached_data.values())} cities in {len(cached_data)} countries")
    print(f"{'='*60}")

if __name__ == '__main__':
    print("="*60)
    print("FastWeather Country Expansion Script")
    print(f"Adding {len(NEW_COUNTRIES_WITH_CITIES)} new countries")
    print("="*60)
    main()
