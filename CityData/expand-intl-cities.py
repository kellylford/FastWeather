#!/usr/bin/env python3
"""
Expand international cities cache: adds 20+ more cities per country.
Runs incrementally - safely restartable. Distributes when complete.
Estimated runtime: ~45-60 minutes (Nominatim rate limit: 1 req/sec).
"""

import json
import time
import subprocess
import requests
from pathlib import Path

# Country code map (needed for Nominatim countrycodes param)
COUNTRY_CODES = {
    'Algeria': 'dz', 'Angola': 'ao', 'Argentina': 'ar', 'Armenia': 'am',
    'Australia': 'au', 'Austria': 'at', 'Azerbaijan': 'az', 'Bahrain': 'bh',
    'Bangladesh': 'bd', 'Belgium': 'be', 'Bolivia': 'bo', 'Brazil': 'br',
    'Bulgaria': 'bg', 'Cambodia': 'kh', 'Cameroon': 'cm', 'Canada': 'ca',
    'Chile': 'cl', 'China': 'cn', 'Colombia': 'co', 'Costa Rica': 'cr',
    'Croatia': 'hr', 'Cuba': 'cu', 'Czech Republic': 'cz',
    "Côte d'Ivoire": 'ci', 'Denmark': 'dk', 'Dominican Republic': 'do',
    'Ecuador': 'ec', 'Egypt': 'eg', 'El Salvador': 'sv', 'Ethiopia': 'et',
    'Finland': 'fi', 'France': 'fr', 'Georgia': 'ge', 'Germany': 'de',
    'Ghana': 'gh', 'Greece': 'gr', 'Greenland': 'gl', 'Guatemala': 'gt',
    'Honduras': 'hn', 'Hungary': 'hu', 'India': 'in', 'Indonesia': 'id',
    'Iran': 'ir', 'Iraq': 'iq', 'Ireland': 'ie', 'Israel': 'il',
    'Italy': 'it', 'Jamaica': 'jm', 'Japan': 'jp', 'Jordan': 'jo',
    'Kazakhstan': 'kz', 'Kenya': 'ke', 'Kuwait': 'kw', 'Laos': 'la',
    'Lebanon': 'lb', 'Malaysia': 'my', 'Mexico': 'mx', 'Morocco': 'ma',
    'Mozambique': 'mz', 'Myanmar': 'mm', 'Netherlands': 'nl',
    'New Zealand': 'nz', 'Nigeria': 'ng', 'Norway': 'no', 'Oman': 'om',
    'Pakistan': 'pk', 'Panama': 'pa', 'Paraguay': 'py', 'Peru': 'pe',
    'Philippines': 'ph', 'Poland': 'pl', 'Portugal': 'pt', 'Qatar': 'qa',
    'Romania': 'ro', 'Russia': 'ru', 'Saudi Arabia': 'sa', 'Senegal': 'sn',
    'Serbia': 'rs', 'Singapore': 'sg', 'Slovakia': 'sk', 'Slovenia': 'si',
    'South Africa': 'za', 'South Korea': 'kr', 'Spain': 'es', 'Sweden': 'se',
    'Switzerland': 'ch', 'Taiwan': 'tw', 'Tanzania': 'tz', 'Thailand': 'th',
    'Trinidad and Tobago': 'tt', 'Tunisia': 'tn', 'Turkey': 'tr',
    'Uganda': 'ug', 'Ukraine': 'ua', 'United Arab Emirates': 'ae',
    'United Kingdom': 'gb', 'Uruguay': 'uy', 'Uzbekistan': 'uz',
    'Venezuela': 've', 'Vietnam': 'vn', 'Zimbabwe': 'zw',
}

# 20+ additional cities per country (beyond the existing ~20 already cached)
ADDITIONAL_CITIES = {
    'Algeria': [
        'Sétif', 'Tiaret', 'Béjaïa', 'Blida', 'Tlemcen', 'Biskra', 'Batna',
        'Skikda', 'Chlef', 'Jijel', 'Souk Ahras', 'Mostaganem', 'Médéa',
        'El Oued', 'Tébessa', 'Khenchela', 'Guelma', 'Relizane', 'Ouargla',
        'Sidi Bel Abbès', 'Bordj Bou Arréridj',
    ],
    'Angola': [
        'Lobito', 'Benguela', 'Malanje', 'Namibe', 'Uíge', 'Kuito',
        'Saurimo', 'Menongue', 'Ondjiva', 'Waku Kungo', 'Ndalatando',
        'Sumbe', 'Caxito', 'Mbanza Kongo', 'Dundo', 'Luena', 'Songo',
        'Camaxilo', 'Cazombo', 'Gabela',
    ],
    'Argentina': [
        'Quilmes', 'Almirante Brown', 'Lomas de Zamora', 'Lanús', 'General Roca',
        'Comodoro Rivadavia', 'Río Cuarto', 'San Rafael', 'Merlo', 'Morón',
        'Berazategui', 'Florencio Varela', 'San Isidro', 'Vicente López',
        'Tigre', 'Pilar', 'Campana', 'Pergamino', 'San Nicolás de los Arroyos',
        'Río Gallegos', 'Ushuaia',
    ],
    'Armenia': [
        'Vanadzor', 'Vagharshapat', 'Abovyan', 'Hrazdan', 'Kapan',
        'Gavarr', 'Artashat', 'Goris', 'Alaverdi', 'Sevan',
        'Charentsavan', 'Masis', 'Sisian', 'Ijevan', 'Dilijan',
        'Stepanavan', 'Noyemberyan', 'Vardenis', 'Meghri', 'Martuni',
    ],
    'Australia': [
        'Sunshine Coast', 'Rockhampton', 'Bundaberg', 'Hervey Bay', 'Wagga Wagga',
        'Shepparton', 'Mildura', 'Tamworth', 'Broken Hill', 'Mount Gambier',
        'Alice Springs', 'Kalgoorlie', 'Geraldton', 'Broome', 'Port Hedland',
        'Orange', 'Dubbo', 'Bathurst', 'Goulburn', 'Whyalla',
    ],
    'Austria': [
        'Kaiserslautern', 'Traun', 'Amstetten', 'Lustenau', 'Ansfelden',
        'Mödling', 'Hallein', 'Schwechat', 'Bruck an der Mur', 'Spittal an der Drau',
        'Tulln an der Donau', 'Kufstein', 'Ried im Innkreis', 'Wörgl',
        'Imst', 'Hall in Tirol', 'Schwaz', 'Lienz', 'Völkermarkt', 'Stockerau',
    ],
    'Azerbaijan': [
        'Sumqayit', 'Ganja', 'Mingəçevir', 'Nakhchivan', 'Shaki',
        'Lənkəran', 'Shirvan', 'Quba', 'Göyçay', 'Bərdə',
        'Tovuz', 'Aghstafa', 'Salyan', 'Masalli', 'Sabirabad',
        'Shamkir', 'Khachmaz', 'Imishli', 'Zaqatala', 'Astara',
    ],
    'Bahrain': [
        'Riffa', 'Muharraq', 'Hamad Town', 'A\'ali', 'Isa Town',
        'Sitra', 'Budaiya', 'Jidhafs', 'Al Malikiyah', 'Dar Kulaib',
        'Tubli', 'Sanabis', 'Jidd Haffs', 'Al Hidd', 'Bilad Al Qadeem',
        'Zallaq', 'Dumistan', 'Malkiya', 'Diraz', 'Barbar',
    ],
    'Bangladesh': [
        'Gazipur', 'Narayanganj', 'Sylhet', 'Rajshahi', 'Khulna',
        'Comilla', 'Rangpur', 'Mymensingh', 'Barisal', 'Jessore',
        'Bogura', 'Dinajpur', 'Tongi', 'Narsingdi', 'Saidpur',
        'Pabna', 'Tangail', 'Jamalpur', 'Sirajganj', 'Netrokona',
    ],
    'Belgium': [
        'Bruges', 'Turnhout', 'Sint-Truiden', 'Dendermonde', 'Beveren',
        'Lokeren', 'Halle', 'Waregem', 'Beringen', 'Heist-op-den-Berg',
        'Geel', 'Boom', 'Ypres', 'Poperinge', 'Tongeren',
        'Arlon', 'Marche-en-Famenne', 'Bastogne', 'Diest', 'Ronse',
    ],
    'Bolivia': [
        'Cochabamba', 'El Alto', 'Oruro', 'Sucre', 'Potosí',
        'Tarija', 'Montero', 'Trinidad', 'Yacuiba', 'Riberalta',
        'Guayaramerín', 'Cobija', 'Puerto Suárez', 'Villamontes', 'Camiri',
        'Sacaba', 'Quillacollo', 'Warnes', 'Colcapirhua', 'Tiquipaya',
    ],
    'Brazil': [
        'Belém', 'Goiânia', 'Porto Alegre', 'Recife', 'São Luís',
        'Maceió', 'Natal', 'Teresina', 'Campo Grande', 'João Pessoa',
        'Aracaju', 'Cuiabá', 'Macapá', 'Porto Velho', 'Rio Branco',
        'Boa Vista', 'Palmas', 'Florianópolis', 'Vila Velha', 'Serra',
    ],
    'Bulgaria': [
        'Ruse', 'Stara Zagora', 'Pleven', 'Sliven', 'Dobrich',
        'Shumen', 'Pernik', 'Haskovo', 'Yambol', 'Pazardzhik',
        'Blagoevgrad', 'Veliko Tarnovo', 'Vraca', 'Gabrovo', 'Burgas',
        'Targovishte', 'Montana', 'Kardzhali', 'Lovech', 'Vidin',
    ],
    'Cambodia': [
        'Phnom Penh', 'Siem Reap', 'Battambang', 'Sihanoukville', 'Kampong Cham',
        'Kratié', 'Pursat', 'Kampong Chhnang', 'Kampong Speu', 'Takeo',
        'Prey Veng', 'Svay Rieng', 'Kandal', 'Kep', 'Pailin',
        'Preah Vihear', 'Stung Treng', 'Ratanakiri', 'Mondulkiri', 'Oddar Meanchey',
    ],
    'Cameroon': [
        'Douala', 'Yaoundé', 'Garoua', 'Bamenda', 'Bafoussam',
        'Ngaoundéré', 'Bertoua', 'Loum', 'Kumba', 'Edéa',
        'Nkongsamba', 'Buea', 'Ebolowa', 'Kribi', 'Limbe',
        'Maroua', 'Kousseri', 'Foumban', 'Dschang', 'Bangangté',
    ],
    'Canada': [
        'Laval', 'Brampton', 'Surrey', 'Halifax', 'London',
        'Markham', 'Vaughan', 'Kitchener', 'Hamilton', 'Victoria',
        'Windsor', 'Saskatoon', 'Regina', 'Kelowna', 'Barrie',
        'Sherbrooke', 'Levis', 'Kelowna', 'Abbotsford', 'Trois-Rivières',
    ],
    'Chile': [
        'Antofagasta', 'Viña del Mar', 'Valparaíso', 'Concepción', 'Temuco',
        'Rancagua', 'Talca', 'Arica', 'Chillán', 'Iquique',
        'Puerto Montt', 'Coquimbo', 'La Serena', 'Osorno', 'Valdivia',
        'Punta Arenas', 'Calama', 'Copiapó', 'Curicó', 'Quilpué',
    ],
    'China': [
        'Chongqing', 'Tianjin', 'Chengdu', 'Nanjing', 'Wuhan',
        'Xi\'an', 'Hangzhou', 'Shenyang', 'Harbin', 'Qingdao',
        'Zhengzhou', 'Changchun', 'Kunming', 'Dalian', 'Jinan',
        'Fuzhou', 'Nanning', 'Taiyuan', 'Changsha', 'Urumqi',
    ],
    'Colombia': [
        'Barranquilla', 'Cartagena', 'Cúcuta', 'Soledad', 'Ibagué',
        'Bucaramanga', 'Soacha', 'Santa Marta', 'Villavicencio', 'Pasto',
        'Montería', 'Manizales', 'Neiva', 'Armenia', 'Pereira',
        'Valledupar', 'Sincelejo', 'Popayán', 'Palmira', 'Bello',
    ],
    'Costa Rica': [
        'Alajuela', 'Desamparados', 'Pérez Zeledón', 'Liberia', 'San Carlos',
        'Heredia', 'Cartago', 'Puntarenas', 'Limón', 'Nicoya',
        'Quepos', 'Jacó', 'Grecia', 'Ciudad Quesada', 'Turrialba',
        'Palmares', 'Naranjo', 'Puriscal', 'Garabito', 'Parrita',
    ],
    'Croatia': [
        'Osijek', 'Rijeka', 'Zadar', 'Slavonski Brod', 'Pula',
        'Sisak', 'Karlovac', 'Koprivnica', 'Bjelovar', 'Varaždin',
        'Šibenik', 'Dubrovnik', 'Velika Gorica', 'Samobor', 'Vinkovci',
        'Vukovar', 'Đakovo', 'Požega', 'Čakovec', 'Petrinja',
    ],
    'Cuba': [
        'Santiago de Cuba', 'Camagüey', 'Holguín', 'Guantánamo', 'Santa Clara',
        'Las Tunas', 'Bayamo', 'Cienfuegos', 'Pinar del Río', 'Matanzas',
        'Ciego de Ávila', 'Trinidad', 'Manzanillo', 'Sancti Spíritus',
        'Palma Soriano', 'Nuevitas', 'Morón', 'Cárdenas', 'Colón', 'Sagua la Grande',
    ],
    'Czech Republic': [
        'Ostrava', 'Plzeň', 'Liberec', 'Olomouc', 'České Budějovice',
        'Hradec Králové', 'Ústí nad Labem', 'Pardubice', 'Havířov', 'Zlín',
        'Kladno', 'Most', 'Opava', 'Frýdek-Místek', 'Karviná',
        'Jihlava', 'Teplice', 'Děčín', 'Chomutov', 'Jablonec nad Nisou',
    ],
    "Côte d'Ivoire": [
        'San-Pédro', 'Bouaké', 'Daloa', 'Korhogo', 'Man',
        'Divo', 'Gagnoa', 'Abengourou', 'Katiola', 'Bondoukou',
        'Odienné', 'Séguéla', 'Touba', 'Dimbokro', 'Agboville',
        'Aboisso', 'Sassandra', 'Grand-Bassam', 'Yamoussoukro', 'Adzopé',
    ],
    'Denmark': [
        'Odense', 'Aalborg', 'Esbjerg', 'Randers', 'Kolding',
        'Horsens', 'Vejle', 'Roskilde', 'Helsingør', 'Herning',
        'Silkeborg', 'Næstved', 'Fredericia', 'Viborg', 'Køge',
        'Holstebro', 'Slagelse', 'Sønderborg', 'Hillerød', 'Svendborg',
    ],
    'Dominican Republic': [
        'Santiago de los Caballeros', 'La Romana', 'San Pedro de Macorís',
        'San Cristóbal', 'Puerto Plata', 'La Vega', 'San Francisco de Macorís',
        'Barahona', 'Moca', 'Higuey', 'Salcedo', 'Bonao',
        'Azua', 'Monte Plata', 'Cotui', 'Nagua', 'Baní',
        'Jarabacoa', 'Pedernales', 'Elías Piña',
    ],
    'Ecuador': [
        'Cuenca', 'Santo Domingo', 'Machala', 'Manta', 'Portoviejo',
        'Ambato', 'Riobamba', 'Esmeraldas', 'Quevedo', 'Milagro',
        'Ibarra', 'Loja', 'Babahoyo', 'Latacunga', 'Tulcán',
        'Nueva Loja', 'Puyo', 'Macas', 'Tena', 'Zamora',
    ],
    'Egypt': [
        'Alexandria', 'Giza', 'Port Said', 'Suez', 'Mansoura',
        'Luxor', 'Aswan', 'Ismailia', 'Faiyum', 'Zagazig',
        'Damietta', 'Asyut', 'Beni Suef', 'Tanta', 'Minya',
        'Hurghada', 'Sharm el-Sheikh', 'Sohag', 'Qena', 'Damnhur',
    ],
    'El Salvador': [
        'San Miguel', 'Santa Ana', 'Soyapango', 'Mejicanos', 'Apopa',
        'Delgado', 'Ciudad Arce', 'Ilopango', 'San Marcos', 'Usulután',
        'Zacatecoluca', 'Chalatenango', 'Cojutepeque', 'Sensuntepeque', 'San Vicente',
        'Ahuachapán', 'La Unión', 'Cabañas', 'Nahuizalco', 'Nueva Concepción',
    ],
    'Ethiopia': [
        'Dire Dawa', 'Mekele', 'Gondar', 'Bahir Dar', 'Dessie',
        'Jimma', 'Jijiga', 'Hawassa', 'Adama', 'Harar',
        'Dilla', 'Nekemte', 'Arba Minch', 'Shashamane', 'Hosaena',
        'Wolkite', 'Wolaita Sodo', 'Kombolcha', 'Debre Birhan', 'Debre Markos',
    ],
    'Finland': [
        'Tampere', 'Oulu', 'Turku', 'Jyväskylä', 'Lahti',
        'Kuopio', 'Kouvola', 'Pori', 'Joensuu', 'Lappeenranta',
        'Vaasa', 'Hämeenlinna', 'Rovaniemi', 'Seinäjoki', 'Mikkeli',
        'Kotka', 'Salo', 'Porvoo', 'Hyvinkää', 'Kajaani',
    ],
    'France': [
        'Strasbourg', 'Bordeaux', 'Toulouse', 'Nice', 'Rennes',
        'Reims', 'Saint-Étienne', 'Toulon', 'Grenoble', 'Dijon',
        'Angers', 'Nîmes', 'Villeurbanne', 'Saint-Denis', 'Le Havre',
        'Clermont-Ferrand', 'Aix-en-Provence', 'Brest', 'Limoges', 'Tours',
    ],
    'Georgia': [
        'Kutaisi', 'Batumi', 'Rustavi', 'Zugdidi', 'Gori',
        'Poti', 'Samtredia', 'Khashuri', 'Ozurgeti', 'Zestaponi',
        'Akhaltsikhe', 'Telavi', 'Mtskheta', 'Senaki', 'Tqibuli',
        'Chiatura', 'Tsqaltubo', 'Tkibuli', 'Ambrolauri', 'Kaspi',
    ],
    'Germany': [
        'Essen', 'Dortmund', 'Düsseldorf', 'Leipzig', 'Dresden',
        'Hannover', 'Nuremberg', 'Duisburg', 'Bochum', 'Wuppertal',
        'Bielefeld', 'Bonn', 'Mannheim', 'Karlsruhe', 'Augsburg',
        'Wiesbaden', 'Gelsenkirchen', 'Mönchengladbach', 'Braunschweig', 'Kiel',
    ],
    'Ghana': [
        'Kumasi', 'Tamale', 'Sekondi-Takoradi', 'Sunyani', 'Cape Coast',
        'Obuasi', 'Teshie', 'Tema', 'Ho', 'Koforidua',
        'Wa', 'Bolgatanga', 'Techiman', 'Prestea', 'Nkoranza',
        'Dormaa Ahenkro', 'Winneba', 'Salaga', 'Juaben', 'Berekum',
    ],
    'Greece': [
        'Thessaloniki', 'Patras', 'Heraklion', 'Larissa', 'Volos',
        'Ioannina', 'Trikala', 'Chalcis', 'Serres', 'Alexandroupoli',
        'Xanthi', 'Kavala', 'Katerini', 'Agrinio', 'Lamia',
        'Kalamata', 'Rhodes', 'Corfu', 'Chania', 'Drama',
    ],
    'Greenland': [
        'Sisimiut', 'Ilulissat', 'Qaqortoq', 'Aasiaat', 'Maniitsoq',
        'Tasiilaq', 'Paamiut', 'Narsaq', 'Narsarsuaq', 'Qaanaaq',
        'Upernavik', 'Kangerlussuaq', 'Ittoqqortoormiit', 'Uummannaq', 'Nanortalik',
        'Qasigiannguit', 'Qeqertarsuaq', 'Kangaatsiaq', 'Alluitsup Paa', 'Arsuk',
    ],
    'Guatemala': [
        'Mixco', 'Villa Nueva', 'Quetzaltenango', 'Escuintla', 'Chinautla',
        'San Juan Sacatepéquez', 'Villa Canales', 'Huehuetenango',
        'Cobán', 'Antigua Guatemala', 'Chimaltenango', 'Jalapa',
        'Retalhuleu', 'Zacapa', 'Jutiapa', 'Mazatenango', 'Puerto Barrios',
        'Flores', 'Chiquimula', 'Santa Lucía Cotzumalguapa',
    ],
    'Honduras': [
        'San Pedro Sula', 'Choloma', 'La Ceiba', 'El Progreso', 'Choluteca',
        'Comayagua', 'Puerto Cortés', 'Danlí', 'Siguatepeque', 'Juticalpa',
        'Tela', 'Santa Rosa de Copán', 'Olanchito', 'Villanueva', 'Catacamas',
        'Tocoa', 'Yoro', 'Nacaome', 'La Lima', 'Roatán',
    ],
    'Hungary': [
        'Debrecen', 'Miskolc', 'Pécs', 'Győr', 'Nyíregyháza',
        'Kecskemét', 'Székesfehérvár', 'Szombathely', 'Szolnok', 'Érd',
        'Tatabánya', 'Kaposvár', 'Veszprém', 'Zalaegerszeg', 'Sopron',
        'Eger', 'Salgótarján', 'Dunaújváros', 'Hódmezővásárhely', 'Szekszárd',
    ],
    'India': [
        'Delhi', 'Mumbai', 'Bangalore', 'Hyderabad', 'Ahmedabad',
        'Chennai', 'Kolkata', 'Surat', 'Pune', 'Jaipur',
        'Lucknow', 'Kanpur', 'Nagpur', 'Indore', 'Thane',
        'Bhopal', 'Visakhapatnam', 'Patna', 'Vadodara', 'Ghaziabad',
    ],
    'Indonesia': [
        'Surabaya', 'Bandung', 'Bekasi', 'Medan', 'Tangerang',
        'Depok', 'Semarang', 'Palembang', 'South Tangerang', 'Makassar',
        'Batam', 'Pekanbaru', 'Bandar Lampung', 'Malang', 'Padang',
        'Denpasar', 'Samarinda', 'Banjarmasin', 'Pontianak', 'Manado',
    ],
    'Iran': [
        'Mashhad', 'Isfahan', 'Tehran', 'Karaj', 'Tabriz',
        'Shiraz', 'Ahvaz', 'Qom', 'Kermanshah', 'Urmia',
        'Rasht', 'Zahedan', 'Hamadan', 'Arak', 'Yazd',
        'Ardabil', 'Bandar Abbas', 'Sari', 'Bojnurd', 'Birjand',
    ],
    'Iraq': [
        'Basra', 'Mosul', 'Najaf', 'Erbil', 'Karbala',
        'Nasiriyah', 'Sulaymaniyah', 'Hilla', 'Kirkuk', 'Kut',
        'Ramadi', 'Samarra', 'Fallujah', 'Baqubah', 'Tikrit',
        'Dohuk', 'Amarah', 'Diwaniyah', 'Ar Rutbah', 'Mandali',
    ],
    'Ireland': [
        'Cork', 'Limerick', 'Galway', 'Waterford', 'Drogheda',
        'Dundalk', 'Bray', 'Navan', 'Kilkenny', 'Ennis',
        'Carlow', 'Tralee', 'Sligo', 'Athlone', 'Tullamore',
        'Wexford', 'Letterkenny', 'Celbridge', 'Clonmel', 'Swords',
    ],
    'Israel': [
        'West Jerusalem', 'Tel Aviv', 'Haifa', 'Rishon LeZion', 'Petah Tikva',
        'Ashdod', 'Netanya', 'Beer Sheva', 'Bnei Brak', 'Holon',
        'Bat Yam', 'Ramat Gan', 'Ashkelon', 'Herzliya', 'Kfar Saba',
        'Rehovot', 'Beit Shemesh', 'Nazareth', 'Lod', 'Ramla',
    ],
    'Italy': [
        'Turin', 'Palermo', 'Genoa', 'Bologna', 'Florence',
        'Bari', 'Catania', 'Venice', 'Verona', 'Messina',
        'Padua', 'Trieste', 'Brescia', 'Taranto', 'Prato',
        'Reggio Calabria', 'Modena', 'Reggio Emilia', 'Perugia', 'Livorno',
    ],
    'Jamaica': [
        'Portmore', 'Spanish Town', 'Montego Bay', 'May Pen', 'Mandeville',
        'Old Harbour', 'Linstead', 'Ocho Rios', 'Half Way Tree',
        'Savanna-la-Mar', 'Port Antonio', 'Falmouth', 'Black River',
        'Negril', 'Lluidas Vale', 'Chapelton', 'Christiana', 'Morant Bay',
        'Bath', 'Port Maria',
    ],
    'Japan': [
        'Osaka', 'Nagoya', 'Sapporo', 'Fukuoka', 'Kobe',
        'Kyoto', 'Kawasaki', 'Saitama', 'Hiroshima', 'Sendai',
        'Chiba', 'Kitakyushu', 'Sakai', 'Niigata', 'Hamamatsu',
        'Kumamoto', 'Sagamihara', 'Okayama', 'Shizuoka', 'Kagoshima',
    ],
    'Jordan': [
        'Zarqa', 'Irbid', 'Russeifa', 'Aqaba', 'Mafraq',
        'Madaba', 'Karak', 'Tafilah', 'Maan', 'Salt',
        'Jerash', 'Ajloun', 'Ramtha', 'Al-Aqabah', 'Azraq',
        'Sahab', 'Fuheies', 'Khirbet as-Samra', 'Turra', 'Sama',
    ],
    'Kazakhstan': [
        'Almaty', 'Astana', 'Shymkent', 'Karagandy', 'Aktobe',
        'Taraz', 'Pavlodar', 'Ust-Kamenogorsk', 'Semey', 'Atyrau',
        'Kostanay', 'Kyzylorda', 'Uralsk', 'Petropavl', 'Aktau',
        'Temirtau', 'Turkestan', 'Ekibastuz', 'Rudny', 'Zhezkazgan',
    ],
    'Kenya': [
        'Mombasa', 'Kisumu', 'Nakuru', 'Eldoret', 'Malindi',
        'Thika', 'Ruiru', 'Kikuyu', 'Kisii', 'Nyeri',
        'Meru', 'Kitale', 'Garissa', 'Machakos', 'Kericho',
        'Embu', 'Kakamega', 'Migori', 'Homa Bay', 'Bungoma',
    ],
    'Kuwait': [
        'Farwaniyah', 'Jahra', 'Mubarak Al-Kabeer', 'Ahmadi', 'Hawalli',
        'Salmiya', 'Sabah Al-Salem', 'Rumaithiya', 'Abu Halifa', 'Fahaheel',
        'Mangaf', 'Mahboula', 'Fintas', 'Egaila', 'Wafra',
        'Sulaibiya', 'Khaitan', 'Shamia', 'Dasma', 'Bayan',
    ],
    'Laos': [
        'Pakse', 'Savannakhet', 'Luang Prabang', 'Thakhek', 'Kaysone Phomvihane',
        'Xam Neua', 'Luang Namtha', 'Attapeu', 'Phonsali', 'Ban Houayxay',
        'Phongsali', 'Muang Xay', 'Muang Sing', 'Xaignabouli', 'Pakxan',
        'Tha Khaek', 'Muang Phine', 'Champasak', 'Muang Khong', 'Saravan',
    ],
    'Lebanon': [
        'Tripoli', 'Sidon', 'Tyre', 'Jounieh', 'Zahle',
        'Baalbek', 'Byblos', 'Nabatieh', 'Halba', 'Zghorta',
        'Ehden', 'Aley', 'Baabda', 'Deir el Ahmar', 'Rachaya',
        'Hasbaya', 'Marjayoun', 'Bint Jbeil', 'Jezzine', 'Chouf',
    ],
    'Malaysia': [
        'Kuala Lumpur', 'George Town', 'Ipoh', 'Petaling Jaya', 'Subang Jaya',
        'Shah Alam', 'Johor Bahru', 'Kota Kinabalu', 'Kuching', 'Malacca City',
        'Alor Setar', 'Kota Bharu', 'Seremban', 'Kuala Terengganu', 'Sandakan',
        'Tawau', 'Miri', 'Sibu', 'Bintulu', 'Taiping',
    ],
    'Mexico': [
        'Guadalajara', 'Monterrey', 'Puebla', 'Toluca', 'Tijuana',
        'León', 'Juárez', 'Torreón', 'San Luis Potosí', 'Mérida',
        'Aguascalientes', 'Tampico', 'Cancún', 'Acapulco', 'Chihuahua',
        'Morelia', 'Querétaro', 'Culiacán', 'Mazatlán', 'Hermosillo',
    ],
    'Morocco': [
        'Fes', 'Marrakesh', 'Agadir', 'Meknes', 'Oujda',
        'Kenitra', 'Tetouan', 'Safi', 'El Jadida', 'Béni Mellal',
        'Nador', 'Khouribga', 'Taza', 'Mohammedia', 'Laâyoune',
        'Dakhla', 'Tiznit', 'Khénifra', 'Settat', 'Taroudant',
    ],
    'Mozambique': [
        'Matola', 'Nampula', 'Beira', 'Chimoio', 'Nacala',
        'Quelimane', 'Tete', 'Xai-Xai', 'Lichinga', 'Pemba',
        'Inhambane', 'Mocuba', 'Gurue', 'Cuamba', 'Moçambique Island',
        'Montepuez', 'Maxixe', 'Dondo', 'Angoche', 'Milange',
    ],
    'Myanmar': [
        'Yangon', 'Mandalay', 'Naypyidaw', 'Mawlamyine', 'Bago',
        'Pathein', 'Meiktila', 'Myeik', 'Sittwe', 'Taunggyi',
        'Lashio', 'Pakokku', 'Hpa-an', 'Dawei', 'Pyay',
        'Myingyan', 'Magway', 'Sagaing', 'Shwebo', 'Kyaukse',
    ],
    'Netherlands': [
        'Rotterdam', 'Den Haag', 'Utrecht', 'Eindhoven', 'Tilburg',
        'Groningen', 'Almere', 'Breda', 'Nijmegen', 'Enschede',
        'Arnhem', 'Haarlem', 'Zaanstat', 'Amersfoort', 'Apeldoorn',
        's-Hertogenbosch', 'Zwolle', 'Maastricht', 'Dordrecht', 'Leiden',
    ],
    'New Zealand': [
        'Christchurch', 'Hamilton', 'Tauranga', 'Lower Hutt', 'Palmerston North',
        'Dunedin', 'Nelson', 'Rotorua', 'New Plymouth', 'Whangarei',
        'Invercargill', 'Napier', 'Hastings', 'Upper Hutt', 'Gisborne',
        'Blenheim', 'Porirua', 'Whanganui', 'Timaru', 'Queenstown',
    ],
    'Nigeria': [
        'Lagos', 'Kano', 'Ibadan', 'Kaduna', 'Port Harcourt',
        'Benin City', 'Maiduguri', 'Zaria', 'Aba', 'Enugu',
        'Onitsha', 'Warri', 'Sokoto', 'Ogbomosho', 'Ilorin',
        'Calabar', 'Uyo', 'Akure', 'Bauchi', 'Jos',
    ],
    'Norway': [
        'Bergen', 'Trondheim', 'Stavanger', 'Bærum', 'Kristiansand',
        'Fredrikstad', 'Tromsø', 'Sandnes', 'Drammen', 'Sarpsborg',
        'Skien', 'Bodø', 'Ålesund', 'Sandefjord', 'Haugesund',
        'Moss', 'Tønsberg', 'Arendal', 'Gjøvik', 'Hamar',
    ],
    'Oman': [
        'Seeb', 'Salalah', 'Bawshar', 'Sohar', 'As Suwayq',
        'Ibri', 'Saham', 'Barka', 'Rustaq', 'Al Buraimi',
        'Nizwa', 'Sur', 'Bahla', 'Izki', 'Khasab',
        'Muscat', 'Shinas', 'Liwa', 'Adam', 'Haima',
    ],
    'Pakistan': [
        'Lahore', 'Faisalabad', 'Rawalpindi', 'Gujranwala', 'Peshawar',
        'Multan', 'Hyderabad', 'Islamabad', 'Quetta', 'Bahawalpur',
        'Sargodha', 'Sialkot', 'Sukkur', 'Larkana', 'Sheikhupura',
        'Jhang', 'Rahim Yar Khan', 'Gujrat', 'Mardan', 'Kasur',
    ],
    'Panama': [
        'San Miguelito', 'La Chorrera', 'Tocumen', 'David', 'Colón',
        'Pacora', 'Arraiján', 'Nuevo Veraguas', 'Las Cumbres', 'Changuinola',
        'Pedregal', 'Penonomé', 'Chitré', 'Santiago', 'Los Santos',
        'Aguadulce', 'Boquete', 'El Valle', 'Portobelo', 'La Palma',
    ],
    'Paraguay': [
        'Ciudad del Este', 'San Lorenzo', 'Luque', 'Capiatá', 'Lambaré',
        'Fernando de la Mora', 'Limpio', 'Ñemby', 'Pedro Juan Caballero',
        'Encarnación', 'Caaguazú', 'Coronel Oviedo', 'Concepción',
        'Villarrica', 'Pilar', 'Nemby', 'Mariano Roque Alonso',
        'Caacupe', 'Itauguá', 'Villa Elisa',
    ],
    'Peru': [
        'Arequipa', 'Trujillo', 'Chiclayo', 'Huancayo', 'Piura',
        'Iquitos', 'Cusco', 'Chimbote', 'Pucallpa', 'Tacna',
        'Cajamarca', 'Ica', 'Juliaca', 'Chincha Alta', 'Ayacucho',
        'Huánuco', 'Puno', 'Tumbes', 'Moquegua', 'Tarapoto',
    ],
    'Philippines': [
        'Quezon City', 'Davao City', 'Manila', 'Caloocan', 'Zamboanga City',
        'Cebu City', 'Antipolo', 'Taguig', 'Valenzuela', 'Pasig',
        'Cagayan de Oro', 'Dasmariñas', 'Bacoor', 'General Santos', 'Paranaque',
        'Las Piñas', 'Marikina', 'Pasay', 'Bacolod', 'Iloilo City',
    ],
    'Poland': [
        'Krakow', 'Lodz', 'Wroclaw', 'Poznan', 'Gdansk',
        'Szczecin', 'Bydgoszcz', 'Lublin', 'Katowice', 'Bialystok',
        'Gdynia', 'Czestochowa', 'Sosnowiec', 'Radom', 'Torun',
        'Kielce', 'Rzeszow', 'Gliwice', 'Zabrze', 'Olsztyn',
    ],
    'Portugal': [
        'Porto', 'Vila Nova de Gaia', 'Amadora', 'Braga', 'Setúbal',
        'Coimbra', 'Funchal', 'Almada', 'Agualva-Cacém', 'Queluz',
        'Aveiro', 'Viseu', 'Guimarães', 'Évora', 'Leiria',
        'Faro', 'Castelo Branco', 'Beja', 'Portalegre', 'Viana do Castelo',
    ],
    'Qatar': [
        'Al Rayyan', 'Umm Salal', 'Al Wakrah', 'Al Khor', 'Ash Shahaniyah',
        'Madinat ash Shamal', 'Dukhan', 'Al Wukair', 'Al Thakhira',
        'Mesaieed', 'Lusail', 'Al Kharayej', 'Simaisma', 'Ain Khalid',
        'Al Wakair', 'Barwa City', 'Al Gharrafa', 'Muaither', 'Al Sailiya', 'Al Hilal',
    ],
    'Romania': [
        'Cluj-Napoca', 'Timișoara', 'Iași', 'Constanța', 'Craiova',
        'Galați', 'Brașov', 'Ploiești', 'Oradea', 'Brăila',
        'Bacău', 'Arad', 'Pitești', 'Sibiu', 'Târgu Mureș',
        'Baia Mare', 'Buzău', 'Botoșani', 'Satu Mare', 'Râmnicu Vâlcea',
    ],
    'Russia': [
        'St. Petersburg', 'Novosibirsk', 'Yekaterinburg', 'Nizhny Novgorod', 'Kazan',
        'Chelyabinsk', 'Omsk', 'Samara', 'Ufa', 'Krasnoyarsk',
        'Perm', 'Voronezh', 'Volgograd', 'Saratov', 'Krasnodar',
        'Tolyatti', 'Ulyanovsk', 'Izhevsk', 'Barnaul', 'Vladivostok',
    ],
    'Saudi Arabia': [
        'Medina', 'Mecca', 'Dammam', 'Jeddah', 'Taif',
        'Tabuk', 'Buraidah', 'Khobar', 'Abha', 'Khamis Mushait',
        'Jubail', 'Hafar Al-Batin', 'Hail', 'Al Qatif', 'Yanbu',
        'Al Ahsa', 'Najran', 'Jizan', 'Sakaka', 'Arar',
    ],
    'Senegal': [
        'Touba', 'Thiès', 'Rufisque', 'Ziguinchor', 'Saint-Louis',
        'Kaolack', 'Mbour', 'Kolda', 'Tambacounda', 'Richard-Toll',
        'Louga', 'Matam', 'Diourbel', 'Fatick', 'Sédhiou',
        'Kaffrine', 'Kédougou', 'Podor', 'Vélingara', 'Bignona',
    ],
    'Serbia': [
        'Novi Sad', 'Niš', 'Kragujevac', 'Subotica', 'Zrenjanin',
        'Pančevo', 'Čačak', 'Novi Pazar', 'Smederevo', 'Valjevo',
        'Leskovac', 'Vranje', 'Šabac', 'Zaječar', 'Sombor',
        'Pirot', 'Bor', 'Prokuplje', 'Kruševac', 'Požarevac',
    ],
    'Singapore': [
        'Jurong East', 'Woodlands', 'Tampines', 'Sengkang', 'Punggol',
        'Bedok', 'Ang Mo Kio', 'Toa Payoh', 'Bishan', 'Queenstown',
        'Clementi', 'Boon Lay', 'Buona Vista', 'Hougang', 'Serangoon',
        'Yishun', 'Choa Chu Kang', 'Pasir Ris', 'Bukit Batok', 'Geylang',
    ],
    'Slovakia': [
        'Košice', 'Prešov', 'Žilina', 'Nitra', 'Banská Bystrica',
        'Trenčín', 'Trnava', 'Martin', 'Poprad', 'Prievidza',
        'Zvolen', 'Považská Bystrica', 'Michalovce', 'Nové Zámky', 'Spišská Nová Ves',
        'Komárno', 'Záhorie', 'Liptovský Mikuláš', 'Stará Ľubovňa', 'Ružomberok',
    ],
    'Slovenia': [
        'Maribor', 'Celje', 'Kranj', 'Koper', 'Velenje',
        'Novo Mesto', 'Ptuj', 'Trbovlje', 'Kamnik', 'Nova Gorica',
        'Murska Sobota', 'Slovenj Gradec', 'Jesenice', 'Postojna', 'Izola',
        'Piran', 'Domžale', 'Škofja Loka', 'Ravne na Koroškem', 'Ajdovščina',
    ],
    'South Africa': [
        'Cape Town', 'Durban', 'Johannesburg', 'Soweto', 'Port Elizabeth',
        'Pietermaritzburg', 'Benoni', 'Tembisa', 'East London', 'Vereeniging',
        'Bloemfontein', 'Boksburg', 'Welkom', 'Newcastle', 'Krugersdorp',
        'Randburg', 'Roodepoort', 'Witbank', 'Pretoria', 'Midrand',
    ],
    'South Korea': [
        'Seoul', 'Busan', 'Incheon', 'Daegu', 'Daejeon',
        'Gwangju', 'Suwon', 'Ulsan', 'Changwon', 'Seongnam',
        'Goyang', 'Yongin', 'Bucheon', 'Cheongju', 'Ansan',
        'Naju', 'Jeonju', 'Anyang', 'Cheonan', 'Pohang',
    ],
    'Spain': [
        'Barcelona', 'Valencia', 'Seville', 'Zaragoza', 'Málaga',
        'Murcia', 'Palma', 'Las Palmas', 'Bilbao', 'Alicante',
        'Córdoba', 'Valladolid', 'Vigo', 'Gijón', 'Hospitalet de Llobregat',
        'A Coruña', 'Vitoria-Gasteiz', 'Granada', 'Elche', 'Oviedo',
    ],
    'Sweden': [
        'Gothenburg', 'Malmö', 'Uppsala', 'Sollentuna', 'Linköping',
        'Västerås', 'Örebro', 'Helsingborg', 'Norrköping', 'Jönköping',
        'Umeå', 'Lund', 'Borås', 'Sundsvall', 'Gävle',
        'Eskilstuna', 'Södertälje', 'Karlstad', 'Täby', 'Halmstad',
    ],
    'Switzerland': [
        'Geneva', 'Basel', 'Lausanne', 'Bern', 'Winterthur',
        'Lucerne', 'St. Gallen', 'Lugano', 'Biel/Bienne', 'Thun',
        'Köniz', 'La Chaux-de-Fonds', 'Schaffhausen', 'Fribourg', 'Chur',
        'Vernier', 'Neuchâtel', 'Uster', 'Sion', 'Emmen',
    ],
    'Taiwan': [
        'New Taipei City', 'Kaohsiung', 'Taichung', 'Tainan', 'Taoyuan',
        'Hsinchu', 'Keelung', 'Chiayi', 'Changhua', 'Zhongli',
        'Pingzhen', 'Xinying', 'Yilan', 'Taitung', 'Hualien',
        'Douliu', 'Miaoli', 'Nantou', 'Banqiao', 'Xinzhuang',
    ],
    'Tanzania': [
        'Dar es Salaam', 'Mwanza', 'Arusha', 'Dodoma', 'Mbeya',
        'Morogoro', 'Tanga', 'Kahama', 'Tabora', 'Zanzibar City',
        'Kigoma', 'Sumbawanga', 'Kasulu', 'Mtwara', 'Musoma',
        'Shinyanga', 'Bukoba', 'Iringa', 'Moshi', 'Lindi',
    ],
    'Thailand': [
        'Bangkok', 'Nonthaburi', 'Pak Kret', 'Hat Yai', 'Chiang Mai',
        'Udon Thani', 'Surat Thani', 'Ubon Ratchathani', 'Nakhon Ratchasima', 'Khon Kaen',
        'Chiang Rai', 'Phuket', 'Nakhon Si Thammarat', 'Pathum Thani', 'Samut Prakan',
        'Nakhon Pathom', 'Rayong', 'Chonburi', 'Kanchanaburi', 'Phitsanulok',
    ],
    'Trinidad and Tobago': [
        'Chaguanas', 'San Fernando', 'Port of Spain', 'Arima', 'Point Fortin',
        'Sangre Grande', 'Couva', 'Debe', 'Princes Town', 'Rio Claro',
        'Laventille', 'Tunapuna', 'Siparia', 'Moruga', 'Penal',
        'Barataria', 'San Juan', 'Carenage', 'Diego Martin', 'Scarborough',
    ],
    'Tunisia': [
        'Sfax', 'Sousse', 'Kairouan', 'Bizerte', 'Gabès',
        'Ariana', 'Gafsa', 'Monastir', 'Ben Arous', 'Kasserine',
        'Médenine', 'Mahdia', 'Siliana', 'Tataouine', 'Tozeur',
        'Béja', 'Jendouba', 'Kébili', 'Le Kef', 'Nabeul',
    ],
    'Turkey': [
        'Ankara', 'Izmir', 'Bursa', 'Antalya', 'Konya',
        'Adana', 'Gaziantep', 'Kocaeli', 'Şanlıurfa', 'Diyarbakır',
        'Mersin', 'Kayseri', 'Eskişehir', 'Denizli', 'Trabzon',
        'Samsun', 'Adapazarı', 'Malatya', 'Kahramanmaraş', 'Van',
    ],
    'Uganda': [
        'Kampala', 'Gulu', 'Lira', 'Mbarara', 'Jinja',
        'Bwizibwera', 'Mukono', 'Kasese', 'Masaka', 'Mbale',
        'Hoima', 'Entebbe', 'Tororo', 'Soroti', 'Kabale',
        'Fort Portal', 'Mityana', 'Mubende', 'Iganga', 'Arua',
    ],
    'Ukraine': [
        'Kharkiv', 'Odessa', 'Dnipro', 'Donetsk', 'Zaporizhzhia',
        'Lviv', 'Kryvyi Rih', 'Mykolaiv', 'Mariupol', 'Luhansk',
        'Vinnytsia', 'Kherson', 'Poltava', 'Chernihiv', 'Cherkasy',
        'Sumy', 'Zhytomyr', 'Ivano-Frankivsk', 'Ternopil', 'Kirovohrad',
    ],
    'United Arab Emirates': [
        'Dubai', 'Abu Dhabi', 'Sharjah', 'Al Ain', 'Ajman',
        'Ras al-Khaimah', 'Fujairah', 'Umm al-Quwain', 'Khor Fakkan', 'Dibba Al-Fujairah',
        'Madinat Zayed', 'Ruwais', 'Liwa', 'Ghayathi', 'Delma',
        'Al Hamriyah', 'Kalba', 'Khor Khwair', 'Jebel Ali', 'Mussafah',
    ],
    'United Kingdom': [
        'London', 'Birmingham', 'Leeds', 'Glasgow', 'Sheffield',
        'Bradford', 'Liverpool', 'Edinburgh', 'Manchester', 'Bristol',
        'Wakefield', 'Cardiff', 'Coventry', 'Nottingham', 'Leicester',
        'Sunderland', 'Belfast', 'Newcastle upon Tyne', 'Brighton', 'Hull',
    ],
    'Uruguay': [
        'Salto', 'Ciudad de la Costa', 'Paysandú', 'Las Piedras', 'Rivera',
        'Maldonado', 'Tacuarembó', 'Melo', 'Durazno', 'Mercedes',
        'Artigas', 'Colonia del Sacramento', 'San José de Mayo', 'Treinta y Tres',
        'Florida', 'Rocha', 'Trinidad', 'Canelones', 'Young', 'Fray Bentos',
    ],
    'Uzbekistan': [
        'Samarkand', 'Namangan', 'Andijan', 'Fergana', 'Nukus',
        'Karshi', 'Bukhara', 'Kokand', 'Margilan', 'Chirchiq',
        'Angren', 'Jizzakh', 'Navoi', 'Termez', 'Urgench',
        'Nukus', 'Gulistan', 'Zarafshan', 'Mubarek', 'Yangiyer',
    ],
    'Venezuela': [
        'Maracaibo', 'Valencia', 'Barquisimeto', 'Ciudad Guayana', 'Petare',
        'Barcelona', 'Maturín', 'San Cristóbal', 'Maracay', 'Cabimas',
        'Turmero', 'Guarenas', 'Cumaná', 'Mérida', 'Valera',
        'Los Teques', 'Barinas', 'Punto Fijo', 'Puerto La Cruz', 'Guatire',
    ],
    'Vietnam': [
        'Ho Chi Minh City', 'Hanoi', 'Da Nang', 'Hai Phong', 'Bien Hoa',
        'Can Tho', 'Thu Duc', 'Hue', 'Nha Trang', 'Vung Tau',
        'Buon Ma Thuot', 'Quy Nhon', 'Long Xuyen', 'Rach Gia', 'My Tho',
        'Thai Nguyen', 'Vinh', 'Nam Dinh', 'Ha Long', 'Bac Ninh',
    ],
    'Zimbabwe': [
        'Bulawayo', 'Chitungwiza', 'Mutare', 'Gweru', 'Kwekwe',
        'Kadoma', 'Masvingo', 'Chinhoyi', 'Norton', 'Marondera',
        'Ruwa', 'Chegutu', 'Zvishavane', 'Bindura', 'Beitbridge',
        'Redcliff', 'Victoria Falls', 'Hwange', 'Kariba', 'Rusape',
    ],
}


def geocode_city(city_name, country_name, country_code):
    url = 'https://nominatim.openstreetmap.org/search'
    params = {
        'q': f'{city_name}, {country_name}',
        'format': 'json',
        'addressdetails': '1',
        'limit': 1,
    }
    if country_code:
        params['countrycodes'] = country_code
    headers = {'User-Agent': 'FastWeather IntlExpand/1.0'}
    try:
        r = requests.get(url, params=params, headers=headers, timeout=10)
        r.raise_for_status()
        results = r.json()
        if results:
            result = results[0]
            address = result.get('address', {})
            state = (address.get('state') or address.get('province') or
                     address.get('region') or '')
            return {
                'name': city_name,
                'state': state,
                'country': country_name,
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

    total_countries = len(ADDITIONAL_CITIES)
    processed = 0

    for country, new_cities in sorted(ADDITIONAL_CITIES.items()):
        processed += 1
        country_code = COUNTRY_CODES.get(country, '')

        existing = cache.get(country, [])
        existing_names = {c['name'].lower() for c in existing}

        to_add = [c for c in new_cities if c.lower() not in existing_names]
        if not to_add:
            print(f'[{processed}/{total_countries}] {country}: all {len(new_cities)} cities already cached, skipping')
            continue

        print(f'\n[{processed}/{total_countries}] {country} — adding {len(to_add)} cities '
              f'(already have {len(existing)})')

        for i, city in enumerate(to_add, 1):
            print(f'  [{i}/{len(to_add)}] {city}... ', end='', flush=True)
            result = geocode_city(city, country, country_code)
            if result:
                existing.append(result)
                print('✓')
            else:
                print('✗ failed')
            if i < len(to_add):
                time.sleep(1.1)

        cache[country] = existing
        with open(cache_file, 'w', encoding='utf-8') as f:
            json.dump(cache, f, indent=2, ensure_ascii=False)
        print(f'  → Saved. {country} now has {len(existing)} cities.')

        if processed < total_countries:
            print('  Waiting 5s before next country...')
            time.sleep(5)

    total = sum(len(v) for v in cache.values())
    print(f'\n{"="*60}')
    print(f'✅ Expansion complete! {len(cache)} countries, {total} total cities.')
    print(f'{"="*60}')

    # Distribute updated cache to all platforms
    print('\nDistributing to all platforms...')
    result = subprocess.run(['bash', 'distribute-caches.sh'], capture_output=True, text=True)
    print(result.stdout)
    if result.returncode != 0:
        print('Distribution errors:', result.stderr)
    else:
        print('✅ Distribution complete!')


if __name__ == '__main__':
    print('='*60)
    print('FastWeather International Cities Expander')
    print(f'Adding 20+ cities per country to all 101 countries')
    print('Estimated runtime: ~45-60 minutes')
    print('Safely restartable — skips already-cached cities')
    print('='*60)
    main()
