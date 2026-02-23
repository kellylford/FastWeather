#!/usr/bin/env python3
"""
expand-more-countries.py
Adds ~90 new countries (not yet in international-cities-cached.json) with 20+ cities each.
Geocodes via Nominatim at 1 req/sec, saves incrementally, distributes when done.
"""

import json
import time
import os
import subprocess
import urllib.request
import urllib.parse

CACHE_FILE = os.path.join(os.path.dirname(__file__), "international-cities-cached.json")
HEADERS = {"User-Agent": "FastWeather/1.0 (weather app city cache builder)"}

# ---------------------------------------------------------------------------
# ~90 new countries with 20-30 representative cities each
# ---------------------------------------------------------------------------
NEW_COUNTRIES = {
    "Albania": [
        "Tirana", "Durrës", "Vlorë", "Elbasan", "Shkodër", "Fier", "Korçë",
        "Berat", "Lushnjë", "Kavajë", "Gjirokastër", "Sarandë", "Lezhë",
        "Kukës", "Pogradec", "Patos", "Kuçovë", "Laç", "Burrel", "Përmet",
        "Librazhd", "Bulqizë", "Gramsh", "Çorovodë", "Ersekë"
    ],
    "Andorra": [
        "Andorra la Vella", "Escaldes-Engordany", "Encamp", "Sant Julià de Lòria",
        "La Massana", "Ordino", "Canillo", "Pas de la Casa", "El Tarter",
        "Arinsal", "Pal", "Soldeu", "Les Bons", "Santa Coloma", "Anyós",
        "Sispony", "La Cortinada", "Llorts", "Ransol", "El Serrat"
    ],
    "Afghanistan": [
        "Kabul", "Kandahar", "Herat", "Mazar-i-Sharif", "Jalalabad", "Kunduz",
        "Ghazni", "Balkh", "Baghlan", "Pul-e-Khumri", "Taloqan", "Lashkar Gah",
        "Khost", "Farah", "Zaranj", "Sheberghan", "Aybak", "Qalat", "Gardez",
        "Maymana", "Charikar", "Asadabad", "Mehtar Lam", "Bamyan", "Faizabad"
    ],
    "Bahamas": [
        "Nassau", "Lucaya", "Freeport", "West End", "Cooper's Town", "Marsh Harbour",
        "Nichols Town", "Alice Town", "Arthur's Town", "Colonel Hill", "Cockburn Town",
        "Matthew Town", "Dunmore Town", "George Town", "Kemps Bay", "Rock Sound",
        "Governor's Harbour", "High Rock", "Eight Mile Rock", "Andros Town",
        "Fresh Creek", "Mangrove Cay", "Mastic Point", "Deadman's Cay", "Black Point"
    ],
    "Barbados": [
        "Bridgetown", "Speightstown", "Oistins", "Bathsheba", "Holetown",
        "Worthing", "Crane", "Six Cross Roads", "Cane Garden", "Checker Hall",
        "Four Roads", "Boscobelle", "Belleplaine", "Haynesville", "Rock Hall",
        "Welches", "Whitehall", "Carrington", "Bayfield", "Rendezvous Hill",
        "Saint Lawrence", "Maxwell", "Inch Marlow", "Atlantic Shores", "Harmony Hall"
    ],
    "Belarus": [
        "Minsk", "Gomel", "Mogilev", "Vitebsk", "Grodno", "Brest", "Bobruisk",
        "Orsha", "Pinsk", "Baranovichi", "Lida", "Soligorsk", "Molodechno",
        "Novopolotsk", "Polotsk", "Zhlobin", "Slutsk", "Kobrin", "Volkovysk",
        "Mozyr", "Rechitsa", "Svetlogorsk", "Zhodino", "Dzerzhinks", "Bereza"
    ],
    "Belize": [
        "Belize City", "San Ignacio", "Belmopan", "Orange Walk", "Dangriga",
        "Corozal", "Punta Gorda", "Benque Viejo del Carmen", "San Pedro",
        "Caye Caulker", "Placencia", "Hopkins", "Mango Creek", "Crooked Tree",
        "Ladyville", "Hattieville", "Roaring Creek", "Santa Elena", "Xaibe",
        "Chan Pine Ridge", "Libertad", "Sarteneja", "Chunox", "August Pine Ridge", "Carmelita"
    ],
    "Benin": [
        "Cotonou", "Porto-Novo", "Parakou", "Djougou", "Bohicon", "Kandi",
        "Abomey", "Natitingou", "Ouidah", "Lokossa", "Aplahoué", "Malanville",
        "Savalou", "Kétou", "Dassa-Zoumè", "Abomey-Calavi", "Comè", "Savè",
        "Bembèrèkè", "Nikki", "Tchaourou", "Banikoara", "Sakété", "Ifangni", "Sèmè-Kpodji"
    ],
    "Bhutan": [
        "Thimphu", "Phuntsholing", "Paro", "Punakha", "Gelephu", "Samdrup Jongkhar",
        "Mongar", "Trashigang", "Wangdue Phodrang", "Pemagatshel", "Trongsa",
        "Bumthang", "Haa", "Lhuentse", "Zhemgang", "Sarpang", "Dagana",
        "Tsirang", "Gasa", "Trashiyangtse", "Chhukha", "Samtse", "Nganglam",
        "Panbang", "Dewathang"
    ],
    "Bosnia and Herzegovina": [
        "Sarajevo", "Banja Luka", "Tuzla", "Zenica", "Mostar", "Bijeljina",
        "Prijedor", "Brčko", "Bihać", "Doboj", "Trebinje", "Livno",
        "Cazin", "Jajce", "Zvornik", "Travnik", "Goražde", "Sanski Most",
        "Pale", "Foča", "Konjic", "Gračanica", "Lukavac", "Visoko", "Bugojno"
    ],
    "Botswana": [
        "Gaborone", "Francistown", "Molepolole", "Serowe", "Selibe Phikwe",
        "Kanye", "Maun", "Mahalapye", "Mogoditshane", "Lobatse", "Palapye",
        "Ramotswa", "Thamaga", "Janeng", "Mochudi", "Moshupa", "Tutume",
        "Tonota", "Kasane", "Gweta", "Letlhakane", "Orapa", "Jwaneng",
        "Tsabong", "Ghanzi"
    ],
    "Brunei": [
        "Bandar Seri Begawan", "Kuala Belait", "Seria", "Tutong", "Bangar",
        "Muara", "Lumapas", "Jerudong", "Gadong", "Manggis", "Kiulap",
        "Berakas", "Kg Anggerek Desa", "Kg Kiarong", "Kg Rimba", "Kg Beribi",
        "Temburong", "Labu", "Sengkurong", "Kg Pengkalan Batu"
    ],
    "Burkina Faso": [
        "Ouagadougou", "Bobo-Dioulasso", "Koudougou", "Banfora", "Ouahigouya",
        "Pouytenga", "Kaya", "Tenkodogo", "Fada N'gourma", "Dédougou",
        "Ziniaré", "Manga", "Kongoussi", "Réo", "Gaoua", "Dori",
        "Tougan", "Léo", "Nouna", "Boromo", "Yako", "Toma",
        "Diapaga", "Bogandé", "Djibo"
    ],
    "Burundi": [
        "Bujumbura", "Gitega", "Muyinga", "Ruyigi", "Ngozi", "Rumonge",
        "Kirundo", "Makamba", "Muramvya", "Kayanza", "Cibitoke", "Bubanza",
        "Cankuzo", "Mwaro", "Rutana", "Bururi", "Bujumbura Rural", "Gihanga",
        "Mutambu", "Isale", "Kinyinya", "Bukeye", "Mugamba", "Rutovu", "Songa"
    ],
    "Cape Verde": [
        "Praia", "Mindelo", "Santa Maria", "Assomada", "Pedra Badejo",
        "Ribeira Grande", "Espargos", "Tarrafal", "Porto Novo", "São Filipe",
        "Calheta de São Miguel", "Pombas", "Paúl", "Ribeira Brava",
        "Cova Figueira", "Vila do Maio", "Sal Rei", "Vila Nova Sintra",
        "Rabil", "João Teves", "Santa Cruz", "Órgãos", "Boa Vista", "Picos", "Chão Bom"
    ],
    "Central African Republic": [
        "Bangui", "Bimbo", "Mbaïki", "Berbérati", "Kaga-Bandoro", "Bossangoa",
        "Bria", "Bambari", "Bouar", "Bangassou", "Nola", "Sibut",
        "Paoua", "Bozoum", "Carnot", "Mobaye", "Bossembélé", "Gamboula",
        "Ndélé", "Baoro", "Batangafo", "Alindao", "Rafaï", "Zemio", "Obo"
    ],
    "Chad": [
        "N'Djamena", "Moundou", "Sarh", "Abéché", "Kélo", "Koumra",
        "Pala", "Am Timan", "Bongor", "Mongo", "Bol", "Doba",
        "Goz Beïda", "Biltine", "Faya-Largeau", "Massakory", "Dourbali",
        "Bitkine", "Oum Hadjer", "Moussoro", "Massaguet", "Laï", "Kyabé", "Fianga", "Léré"
    ],
    "Comoros": [
        "Moroni", "Mutsamudu", "Fomboni", "Domoni", "Ouani", "Koimbani",
        "Tsimbeo", "Mkazi", "Bandamadji", "Mitsamihouli", "Ntsaoueni",
        "Chindini", "Koni-Djodjo", "Ziwani", "Pomoni", "Moya",
        "Sima", "Bambao Mtsanga", "Dziani", "Mjamaoué"
    ],
    "Democratic Republic of the Congo": [
        "Kinshasa", "Lubumbashi", "Mbuji-Mayi", "Kananga", "Kisangani",
        "Bukavu", "Tshikapa", "Kolwezi", "Likasi", "Goma", "Boma", "Uvira",
        "Butembo", "Matadi", "Mbandaka", "Kikwit", "Mwene-Ditu", "Kalemie",
        "Bunia", "Bandundu", "Gemena", "Isiro", "Bumba", "Kabinda", "Kamina"
    ],
    "Republic of the Congo": [
        "Brazzaville", "Pointe-Noire", "Dolisie", "Nkayi", "Impfondo",
        "Ouesso", "Madingou", "Owando", "Djambala", "Sibiti", "Kinkala",
        "Makoua", "Ewo", "Mossendjo", "Gamboma", "Loutété", "Boko",
        "Boundji", "Fort Rousset", "Zanaga", "Souanké", "Sembe", "Moloundou", "Pokola", "Bétou"
    ],
    "Djibouti": [
        "Djibouti City", "Ali Sabieh", "Dikhil", "Obock", "Tadjourah",
        "Arta", "Holhol", "Goubetto", "Yoboki", "As Eyla", "Balho",
        "Randa", "Guelile", "Khor Angar", "Damerjog", "Loyada",
        "Douda", "Balbala", "Enguela", "Dorale"
    ],
    "Equatorial Guinea": [
        "Malabo", "Bata", "Ebebiyín", "Aconibe", "Añisoc", "Luba",
        "Evinayong", "Mongomo", "Sebe", "Mikomeseng", "Nsok", "Riaba",
        "Rebola", "Moka", "Mengomeyén", "Mbini", "Corisco", "Ayene",
        "Río Campo", "Cogo"
    ],
    "Eritrea": [
        "Asmara", "Keren", "Massawa", "Assab", "Mendefera", "Dekemhare",
        "Adi Keyh", "Barentu", "Teseney", "Agordat", "Nakfa", "Adi Quala",
        "Senafe", "Ghinda", "Nefasit", "Embatkala", "Adi Ugri", "Areza",
        "Adi Daero", "Mai-Mine", "Dbarwa", "Tio", "Hagaz", "Elabered", "Segeneiti"
    ],
    "Estonia": [
        "Tallinn", "Tartu", "Narva", "Pärnu", "Kohtla-Järve", "Viljandi",
        "Rakvere", "Maardu", "Sillamäe", "Kuressaare", "Võru", "Valga",
        "Jõhvi", "Haapsalu", "Keila", "Paide", "Tapa", "Põlva",
        "Kiviõli", "Türi", "Elva", "Saue", "Paldiski", "Jõgeva", "Rapla"
    ],
    "Eswatini": [
        "Mbabane", "Manzini", "Big Bend", "Malkerns", "Nhlangano",
        "Siteki", "Piggs Peak", "Hluti", "Simunye", "Mankayane",
        "Lobamba", "Mhlume", "Tshaneni", "Siphofaneni", "Hlatikulu",
        "Bhunya", "Kwaluseni", "Matsapha", "Motshane", "Ngwenya"
    ],
    "Fiji": [
        "Suva", "Lautoka", "Nadi", "Nasinu", "Labasa", "Ba", "Levuka",
        "Sigatoka", "Savusavu", "Rakiraki", "Tavua", "Korovou",
        "Navua", "Pacific Harbour", "Nausori", "Vatukoula", "Kadavu",
        "Rotuma", "Taveuni", "Koro Island", "Ovalau", "Vanua Levu",
        "Lakeba", "Gau", "Yasawa"
    ],
    "Gabon": [
        "Libreville", "Port-Gentil", "Franceville", "Oyem", "Moanda",
        "Mouila", "Lambaréné", "Tchibanga", "Koulamoutou", "Makokou",
        "Bitam", "Gamba", "Ntoum", "Owendo", "Booué",
        "Mitzic", "Mayumba", "Ndendé", "Mbigou", "Lastoursville",
        "Minvoul", "Lékoumou", "Mounana", "Zanaga", "Aboumi"
    ],
    "Gambia": [
        "Banjul", "Serekunda", "Brikama", "Bakau", "Farafenni",
        "Lamin", "Sukuta", "Soma", "Janjanbureh", "Basse Santa Su",
        "Kerewan", "Mansakonko", "Georgetown", "Mansa Konko", "Bwiam",
        "Essau", "Brufut", "Kololi", "Tanji", "Yundum"
    ],
    "Guinea": [
        "Conakry", "Nzérékoré", "Kindia", "Kankan", "Labé",
        "Guéckédou", "Mamou", "Macenta", "Faranah", "Kissidougou",
        "Dalaba", "Télimélé", "Boké", "Coyah", "Siguiri",
        "Beyla", "Fria", "Kérouané", "Mandiana", "Dinguiraye",
        "Dubréka", "Forécariah", "Boffa", "Koubia", "Koundara"
    ],
    "Guinea-Bissau": [
        "Bissau", "Bafatá", "Gabú", "Bissorã", "Bolama", "Cacheu",
        "Bubaque", "Catió", "Quebo", "Mansôa", "Farim", "Bambadinca",
        "Nhacra", "Pitche", "Sonaco", "Contuboel", "Buruntuma",
        "Cantchungo", "Buba", "Quinhámel"
    ],
    "Guyana": [
        "Georgetown", "Linden", "New Amsterdam", "Anna Regina", "Bartica",
        "Skeldon", "Corriverton", "Rose Hall", "Mahaicony", "Parika",
        "Vreed en Hoop", "Tuschen", "Enmore", "Buxton", "Mahaica",
        "Charity", "Suddie", "Lethem", "Mahdia", "Kwakwani",
        "Orealla", "Springlands", "Cove and John", "Providence", "Diamond"
    ],
    "Haiti": [
        "Port-au-Prince", "Carrefour", "Delmas", "Pétionville", "Croix-des-Bouquets",
        "Cap-Haïtien", "Jacmel", "Les Cayes", "Gonaïves", "Saint-Marc",
        "Léogâne", "Miragoâne", "Hinche", "Port-de-Paix", "Fort-Liberté",
        "Jérémie", "Aquin", "Kenscoff", "Tabarre", "Gressier",
        "Turgeau", "Ganthier", "Thomazeau", "Anse-d'Hainault", "Bainet"
    ],
    "Iceland": [
        "Reykjavik", "Kópavogur", "Hafnarfjörður", "Akureyri", "Reykjanesbær",
        "Garðabær", "Mosfellsbær", "Árborg", "Akranes", "Fjarðabyggð",
        "Ísafjörður", "Vestmannaeyjar", "Seltjarnarnes", "Dalvík", "Egilsstaðir",
        "Húsavík", "Selfoss", "Borgarnes", "Hveragerði", "Siglufjörður",
        "Ólafsvík", "Grundarfjörður", "Stykkishólmur", "Blönduós", "Vopnafjörður"
    ],
    "Kosovo": [
        "Pristina", "Prizren", "Ferizaj", "Peja", "Gjilan",
        "Gjakova", "Mitrovica", "Podujeva", "Vushtrri", "Suhareka",
        "Rahovec", "Dragash", "Kaçanik", "Klina", "Malishevo",
        "Lipjan", "Obiliq", "Drenas", "Kamenica", "Istog",
        "Deçan", "Junik", "Hani i Elezit", "Skenderaj", "Shtime"
    ],
    "Kyrgyzstan": [
        "Bishkek", "Osh", "Jalal-Abad", "Tokmok", "Karakol",
        "Uzgen", "Talas", "Balykchy", "Naryn", "Kara-Suu",
        "Nookat", "Kara-Balta", "Kant", "Belovodskoe", "Isfana",
        "Mailuu-Suu", "Suluktu", "Tash-Komur", "Kochkor-Ata", "Iradan",
        "Kerben", "At-Bashy", "Chaek", "Kazarman", "Cholpon-Ata"
    ],
    "Latvia": [
        "Riga", "Daugavpils", "Liepāja", "Jelgava", "Jūrmala",
        "Ventspils", "Rēzekne", "Valmiera", "Jēkabpils", "Sigulda",
        "Tukums", "Kuldīga", "Ogre", "Cēsis", "Talsi",
        "Saldus", "Dobele", "Bauska", "Ādaži", "Mārupe",
        "Olaine", "Salaspils", "Ludza", "Gulbene", "Balvi"
    ],
    "Lesotho": [
        "Maseru", "Teyateyaneng", "Mafeteng", "Hlotse", "Mohale's Hoek",
        "Quthing", "Qacha's Nek", "Butha-Buthe", "Mokhotlong", "Thaba-Tseka",
        "Maputsoe", "Morija", "Semonkong", "Roma", "Peka",
        "Bela-Bela", "Qachas Nek", "Linakaneng", "Nazareth", "Ha Lejone"
    ],
    "Liberia": [
        "Monrovia", "Gbarnga", "Kakata", "Bensonville", "Harper",
        "Voinjama", "Buchanan", "Zwedru", "Fish Town", "Greenville",
        "Sanniquellie", "Ganta", "Tubmanburg", "Robertsport", "Barclayville",
        "Cestos City", "Toe Town", "Belle Yella", "Bopolu", "Kolahun",
        "Foya", "Gbanga", "Yekepa", "Nimba", "Saclepea"
    ],
    "Libya": [
        "Tripoli", "Benghazi", "Misrata", "Al Bayda", "Ajdabiya",
        "Sabha", "Zawiya", "Zintan", "Derna", "Tobruk",
        "Al Khums", "Zliten", "Gharyan", "Tarhuna", "Sirte",
        "Ghadames", "Murzuq", "Al Jufra", "Brak", "Ubari",
        "Ghat", "Kufra", "Al Marj", "Ras Lanuf", "Brega"
    ],
    "Liechtenstein": [
        "Vaduz", "Schaan", "Balzers", "Triesen", "Eschen",
        "Mauren", "Triesenberg", "Ruggell", "Gamprin", "Schellenberg",
        "Planken"
    ],
    "Lithuania": [
        "Vilnius", "Kaunas", "Klaipėda", "Šiauliai", "Panevėžys",
        "Alytus", "Marijampolė", "Mažeikiai", "Jonava", "Utena",
        "Kėdainiai", "Telšiai", "Visaginas", "Tauragė", "Ukmergė",
        "Plungė", "Kretinga", "Palanga", "Radviliškis", "Šilutė",
        "Druskininkai", "Varėna", "Biržai", "Rokiškis", "Joniškis"
    ],
    "Luxembourg": [
        "Luxembourg City", "Esch-sur-Alzette", "Differdange", "Dudelange",
        "Ettelbruck", "Diekirch", "Wiltz", "Echternach", "Rumelange",
        "Grevenmacher", "Remich", "Mersch", "Vianden", "Clervaux",
        "Pétange", "Sanem", "Bettemburg", "Strassen", "Bertrange", "Hesperange"
    ],
    "Madagascar": [
        "Antananarivo", "Toamasina", "Antsirabe", "Fianarantsoa", "Mahajanga",
        "Toliara", "Antsiranana", "Antanifotsy", "Moramanga", "Ambovombe",
        "Manakara", "Morondava", "Ambanja", "Sambava", "Farafangana",
        "Nosy Be", "Maroantsetra", "Fort Dauphin", "Ihosy", "Betafo",
        "Tsiroanomandidy", "Miarinarivo", "Miandrivazo", "Vangaindrano", "Ambilobe"
    ],
    "Malawi": [
        "Lilongwe", "Blantyre", "Mzuzu", "Zomba", "Kasungu",
        "Mangochi", "Karonga", "Salima", "Nkhotakota", "Nsanje",
        "Balaka", "Dedza", "Rumphi", "Chitipa", "Mulanje",
        "Machinga", "Ntcheu", "Thyolo", "Chiradzulu", "Mchinji",
        "Dowa", "Ntchisi", "Phalombe", "Nkhata Bay", "Likoma"
    ],
    "Maldives": [
        "Malé", "Addu City", "Fuvahmulah", "Kulhudhuffushi", "Thinadhoo",
        "Naifaru", "Eydhafushi", "Manadhoo", "Mahibadhoo", "Fonadhoo",
        "Hithadhoo", "Hulhumalé", "Vilingili", "Felidhoo", "Funadhoo",
        "Dhidhdhoo", "Ugoofaaru", "Rasdhoo", "Velidhoo", "Muli"
    ],
    "Mali": [
        "Bamako", "Sikasso", "Mopti", "Koutiala", "Ségou", "Kayes",
        "Gao", "Kidal", "Tombouctou", "Djenne", "Koulikoro", "San",
        "Markala", "Niono", "Kita", "Bougouni", "Kolondièba",
        "Yanfolila", "Kangaba", "Banamba", "Dioïla", "Fana",
        "Barouéli", "Bla", "Yorosso"
    ],
    "Malta": [
        "Valletta", "Birkirkara", "Mosta", "Qormi", "Żabbar",
        "San Ġwann", "Naxxar", "Żeitun", "Fgura", "Marsaskala",
        "Sliema", "St Julian's", "Msida", "Gżira", "Rabat",
        "Mdina", "Marsaxlokk", "Żurrieq", "Birżebbuġa", "Mellieħa",
        "Paola", "Hamrun", "Vittoriosa", "Cospicua", "Senglea"
    ],
    "Mauritania": [
        "Nouakchott", "Nouadhibou", "Néma", "Kaédi", "Rosso",
        "Kiffa", "Zouerate", "Atar", "Sélibabi", "Tidjikja",
        "Akjoujt", "Aleg", "Djiguenni", "Aioun", "Boghé",
        "Maghama", "Gorgol", "Guidimaka", "Bassikounou", "Timbédra",
        "Oualata", "Boutilimit", "Monguel", "Mbout", "Kankossa"
    ],
    "Mauritius": [
        "Port Louis", "Beau Bassin-Rose Hill", "Vacoas-Phoenix", "Curepipe",
        "Quatre Bornes", "Triolet", "Goodlands", "Centre de Flacq",
        "Mahébourg", "Saint Pierre", "Rose Belle", "Moka",
        "Bambous", "Rivière du Rempart", "Pamplemousses", "Flacq",
        "Grand Baie", "Flic en Flac", "Black River", "Souillac",
        "Rodrigues", "Bel Air", "Roche Bois", "St Jean", "Mon Choisy"
    ],
    "Moldova": [
        "Chișinău", "Tiraspol", "Bălți", "Bender", "Rîbnița",
        "Cahul", "Ungheni", "Soroca", "Orhei", "Dubăsari",
        "Comrat", "Edineț", "Hîncești", "Strășeni", "Drochia",
        "Căușeni", "Florești", "Cimișlia", "Rezina", "Ștefan Vodă",
        "Taraclia", "Glodeni", "Fălești", "Sîngerei", "Soldanești"
    ],
    "Monaco": [
        "Monaco", "Monte Carlo", "La Condamine", "Fontvieille",
        "Moneghetti", "Saint-Roman", "Larvotto", "Les Moulins",
        "La Rousse", "Jardin Exotique"
    ],
    "Mongolia": [
        "Ulaanbaatar", "Erdenet", "Darkhan", "Choibalsan", "Ölgii",
        "Khovd", "Mörön", "Bayankhongor", "Arvaikheer", "Altai",
        "Dalandzadgad", "Dalanzadgad", "Ulaangom", "Zuunharaa", "Sukhbaatar",
        "Sainshand", "Bulgan", "Mandalgovi", "Tsetserleg", "Bayanhongor",
        "Undurkhaan", "Zuunmod", "Nalaikh", "Khan-Uul", "Baganuur"
    ],
    "Montenegro": [
        "Podgorica", "Nikšić", "Herceg Novi", "Pljevlja", "Bijelo Polje",
        "Bar", "Cetinje", "Budva", "Ulcinj", "Kotor",
        "Berane", "Rožaje", "Tivat", "Plav", "Mojkovac",
        "Žabljak", "Kolašin", "Šavnik", "Andrijevica", "Danilovgrad"
    ],
    "Mozambique": [
        "Maputo", "Matola", "Nampula", "Beira", "Chimoio",
        "Nacala", "Quelimane", "Tete", "Xai-Xai", "Maxixe",
        "Inhambane", "Mocuba", "Lichinga", "Pemba", "Cuamba",
        "Montepuez", "Mocímboa da Praia", "Angoche", "Ilha de Moçambique",
        "Vilankulo", "Ressano Garcia", "Dondo", "Moatize", "Milange", "Chókwè"
    ],
    "Namibia": [
        "Windhoek", "Rundu", "Walvis Bay", "Oshakati", "Swakopmund",
        "Katima Mulilo", "Grootfontein", "Rehoboth", "Otjiwarongo", "Ongwediva",
        "Ondangwa", "Gobabis", "Keetmanshoop", "Tsumeb", "Okahandja",
        "Lüderitz", "Mariental", "Outapi", "Omaruru", "Karibib",
        "Usakos", "Okakarara", "Henties Bay", "Aranos", "Gibeon"
    ],
    "Nepal": [
        "Kathmandu", "Pokhara", "Lalitpur", "Biratnagar", "Bharatpur",
        "Birgunj", "Dharan", "Janakpur", "Hetauda", "Butwal",
        "Dhangadhi", "Nepalgunj", "Kirtipur", "Itahari", "Bhairahawa",
        "Damak", "Mechinagar", "Lahan", "Rajbiraj", "Tikapur",
        "Tulsipur", "Ghorahi", "Birendranagar", "Jumla", "Namche Bazaar"
    ],
    "Nicaragua": [
        "Managua", "León", "Masaya", "Chinandega", "Matagalpa",
        "Estelí", "Tipitapa", "Granada", "Ciudad Sandino", "Jinotega",
        "El Viejo", "Juigalpa", "Chichigalpa", "Ocotal", "Somotillo",
        "Puerto Cabezas", "Bluefields", "Corn Island", "Rivas", "Diriamba",
        "Nagarote", "La Paz Centro", "Camoapa", "Santo Tomás", "Jalapa"
    ],
    "Niger": [
        "Niamey", "Zinder", "Maradi", "Agadez", "Tahoua",
        "Dosso", "Tillabéri", "Diffa", "Arlit", "Tessaoua",
        "Konni", "Madaoua", "Mayahi", "Mirriah", "Matameye",
        "Gaya", "Dogondoutchi", "Birni-N'Konni", "Bouza", "Illéla",
        "Keita", "Abalak", "Tchintabaraden", "Ingall", "N'Guigmi"
    ],
    "North Macedonia": [
        "Skopje", "Bitola", "Kumanovo", "Prilep", "Tetovo",
        "Ohrid", "Veles", "Štip", "Gostivar", "Strumica",
        "Kički Anevo", "Debar", "Kičevo", "Gevgelija", "Radoviš",
        "Kavadarci", "Negotino", "Vinica", "Delčevo", "Berovo",
        "Probištip", "Sveti Nikole", "Kratovo", "Kratovo", "Valandovo"
    ],
    "Papua New Guinea": [
        "Port Moresby", "Lae", "Arawa", "Mount Hagen", "Madang",
        "Wewak", "Goroka", "Kimbe", "Kokopo", "Mendi",
        "Rabaul", "Daru", "Lorengau", "Kavieng", "Vanimo",
        "Wabag", "Popondetta", "Alotau", "Kundiawa", "Kiunga",
        "Bulolo", "Wau", "Kerema", "Buka", "Panguna"
    ],
    "Rwanda": [
        "Kigali", "Butare", "Gitarama", "Musanze", "Gisenyi",
        "Byumba", "Cyangugu", "Kabgayi", "Kibungo", "Rwamagana",
        "Kibuye", "Nyagatare", "Muhanga", "Huye", "Rubavu",
        "Rusizi", "Rulindo", "Busogo", "Kinigi", "Gasabo",
        "Kicukiro", "Nyarugenge", "Gicumbi", "Kayonza", "Nyanza"
    ],
    "Saint Lucia": [
        "Castries", "Vieux Fort", "Micoud", "Soufrière", "Dennery",
        "Gros Islet", "Anse-la-Raye", "Canaries", "Laborie", "Choiseul",
        "Mon Repos", "Grace", "Bisée", "Marchand", "Babonneau",
        "Monchy", "Belle Vue", "Bois d'Inde", "Grande Rivière", "Praslin"
    ],
    "Samoa": [
        "Apia", "Falealili", "Faleolo", "Sagaga le Falealupo", "Vaimauga",
        "Tuamasaga", "Anoamaa", "Atua", "Fa'asaleleaga", "Gaga'emauga",
        "Gagaifomauga", "Palauli", "Satupa'itea", "Vaisigano", "Safotu",
        "Saleaula", "Lotofaga", "Lalomanu", "Sili", "Falefa"
    ],
    "San Marino": [
        "City of San Marino", "Serravalle", "Borgo Maggiore", "Domagnano",
        "Fiorentino", "Acquaviva", "Montegiardino", "Faetano", "Chiesanuova"
    ],
    "São Tomé and Príncipe": [
        "São Tomé", "Santo António", "Trindade", "Santana",
        "Neves", "São João dos Angolares", "Guadalupe",
        "Ribeira Afonso", "Santa Cruz", "Aeroporto Internacional"
    ],
    "Sierra Leone": [
        "Freetown", "Bo", "Kenema", "Koidu", "Makeni",
        "Lunsar", "Port Loko", "Magburaka", "Waterloo", "Bonthe",
        "Kailahun", "Kabala", "Moyamba", "Pujehun", "Kambia",
        "Pepel", "Segbwema", "Daru", "Yengema", "Blama",
        "Binkolo", "Rokupr", "Matotoka", "Sumbuya", "Pendembu"
    ],
    "Solomon Islands": [
        "Honiara", "Gizo", "Auki", "Kirakira", "Buala",
        "Tulagi", "Lata", "Tigoa", "Taro", "Malango",
        "Noro", "Munda", "Ringi Cove", "Seghe", "Afio",
        "Avuavu", "Dala", "Fiu", "Pamua", "Marau"
    ],
    "Somalia": [
        "Mogadishu", "Hargeisa", "Berbera", "Kismayo", "Bosaso",
        "Merca", "Baidoa", "Galcaio", "Beledweyne", "Jowhar",
        "Afgooye", "Baraawe", "Dhusamareb", "Garowe", "Burco",
        "Galkacyo", "Beled Hawo", "Las Anod", "Erigavo", "Qardho",
        "Hobyo", "Bu'aale", "Wanlaweyn", "Jamaame", "Luuq"
    ],
    "South Sudan": [
        "Juba", "Malakal", "Wau", "Yei", "Bor",
        "Torit", "Rumbek", "Aweil", "Bentiu", "Kwajok",
        "Nimule", "Gogrial", "Kapoeta", "Maridi", "Mundri",
        "Yambio", "Tambura", "Mvolo", "Terekeka", "Renk",
        "Akobo", "Pibor", "Pochalla", "Nasir", "Kodok"
    ],
    "Sri Lanka": [
        "Colombo", "Dehiwala-Mount Lavinia", "Moratuwa", "Sri Jayawardenepura Kotte",
        "Negombo", "Kandy", "Kalmunai", "Trincomalee", "Batticaloa",
        "Jaffna", "Galle", "Anuradhapura", "Ratnapura", "Badulla",
        "Matara", "Amparai", "Kurunegala", "Puttalam", "Mannar",
        "Vavuniya", "Nuwara Eliya", "Tangalle", "Hikkaduwa", "Dambulla", "Polonnaruwa"
    ],
    "Sudan": [
        "Omdurman", "Khartoum", "Khartoum North", "Port Sudan", "Kassala",
        "Obeid", "Atbara", "Gedaref", "Wad Madani", "Al Qadarif",
        "Nyala", "El Fasher", "El Daein", "Geneina", "Zalingei",
        "Dongola", "Sennar", "Rabak", "Kosti", "Abu Zabad",
        "Ed Damer", "Berber", "Halfa", "Tokar", "Kadugli"
    ],
    "Suriname": [
        "Paramaribo", "Lelydorp", "Nieuw Nickerie", "Moengo", "Nieuw Amsterdam",
        "Marienburg", "Brownsweg", "Albina", "Pamaribo-Noord", "Groningen",
        "Wageningen", "Totness", "Apoera", "Brokopondo", "Onverwacht",
        "Mungo", "Meerzorg", "Santigron", "Sarah Maria", "Ephraimszegen"
    ],
    "Syria": [
        "Damascus", "Aleppo", "Homs", "Latakia", "Deir ez-Zor",
        "Hama", "Raqqa", "Al-Hasakah", "Qamishli", "Tartus",
        "Manbij", "Idlib", "Daraa", "Al Bab", "Suwayda",
        "Quneitra", "Palmyra", "Ar-Raqqah", "Douma", "Jaramana",
        "Al-Mayadin", "Kobane", "Azaz", "Afrin", "Ras al-Ayn"
    ],
    "Tajikistan": [
        "Dushanbe", "Khujand", "Kulob", "Qurghonteppa", "Istaravshan",
        "Tursunzoda", "Vahdat", "Panjakent", "Rogun", "Konibodom",
        "Isfara", "Ghafurov", "Norak", "Hisor", "Shahritus",
        "Sarband", "Qabodiyon", "Kolkhozobod", "Shurobod", "Murgab",
        "Khorugh", "Ishkoshim", "Vanj", "Rushan", "Darvoz"
    ],
    "Timor-Leste": [
        "Dili", "Baucau", "Maliana", "Suai", "Lospalos",
        "Manatuto", "Ainaro", "Same", "Viqueque", "Liquiçá",
        "Ermera", "Aileu", "Bobonaro", "Gleno", "Ataúro",
        "Manufahi", "Zumalai", "Railaco", "Lautem", "Oecusse"
    ],
    "Togo": [
        "Lomé", "Sokodé", "Kara", "Datcha", "Kpalimé",
        "Atakpamé", "Tsévié", "Aného", "Sansanné-Mango", "Bassar",
        "Niamtougou", "Blitta", "Sotouboua", "Tchamba", "Tabligbo",
        "Notsé", "Badou", "Agboville", "Vogan", "Amlame",
        "Adeta", "Dapaong", "Cinkassé", "Kantindi", "Gando"
    ],
    "Tonga": [
        "Nuku'alofa", "Neiafu", "Haveluloto", "Vaini", "Pangai",
        "'Ohonua", "Hihifo", "Lapaha", "Kolofo'ou", "Fua'amotu",
        "Ngeshe", "Ha'apai", "Vava'u", "Niuas", "Tatakamotonga",
        "'Eua", "Nomuka", "Lifuka", "Niuafo'ou", "Niuatoputapu"
    ],
    "Trinidad and Tobago": [
        "Port of Spain", "San Fernando", "Chaguanas", "Mon Repos",
        "Arima", "Marabella", "Couva", "Point Fortin", "Scarborough",
        "Diego Martin", "Siparia", "Sangre Grande", "Rio Claro",
        "Princes Town", "Tunapuna", "St. Joseph", "Penal",
        "Debe", "Fyzabad", "La Brea", "Moruga", "Mayaro",
        "Charlotteville", "Plymouth", "Roxborough"
    ],
    "Turkmenistan": [
        "Ashgabat", "Türkmenabat", "Daşoguz", "Mary", "Balkanabat",
        "Bayramaly", "Türkmenbaşy", "Abadan", "Gowurdak",
        "Serdar", "Tejen", "Sarahs", "Kerki", "Atamurat",
        "Gazojak", "Yolöten", "Seydi", "Hazar", "Bereket", "Esenguly"
    ],
    "Uganda": [
        "Kampala", "Gulu", "Lira", "Mbarara", "Jinja",
        "Bwizibwera", "Mbale", "Mukono", "Kasese", "Masaka",
        "Entebbe", "Njeru", "Soroti", "Arua", "Kabale",
        "Iganga", "Fort Portal", "Hoima", "Tororo", "Moroto",
        "Mityana", "Masindi", "Adjumani", "Kotido", "Nebbi"
    ],
    "Vanuatu": [
        "Port Vila", "Luganville", "Norsup", "Lakatoro", "Isangel",
        "Sola", "Longana", "Saratamata", "Lenakel", "Lamap",
        "Craig Cove", "Aneityum", "Dip Point", "Channel Point",
        "Ipota", "Imaio", "Forari", "Mele", "Pango", "Freshwater"
    ],
    "Zambia": [
        "Lusaka", "Kitwe", "Ndola", "Kabwe", "Chingola",
        "Mufulira", "Livingstone", "Luanshya", "Kasama", "Chipata",
        "Kalulushi", "Solwezi", "Mazabuka", "Kafue", "Monze",
        "Choma", "Mongu", "Mansa", "Kapiri Mposhi", "Nakonde",
        "Mpika", "Petauke", "Lundazi", "Isoka", "Sesheke"
    ],
    "Zimbabwe": [
        "Harare", "Bulawayo", "Chitungwiza", "Mutare", "Gweru",
        "Epworth", "Kwekwe", "Kadoma", "Masvingo", "Chinhoyi",
        "Marondera", "Norton", "Ruwa", "Hwange", "Bindura",
        "Beitbridge", "Redcliff", "Victoria Falls", "Chegutu", "Zvishavane",
        "Shurugwi", "Kariba", "Chiredzi", "Karoi", "Gokwe"
    ],
}

# ---------------------------------------------------------------------------

NOMINATIM_URL = "https://nominatim.openstreetmap.org/search"

def geocode_city(city_name: str, country: str):
    """Return (lat, lon) or None if not found."""
    params = urllib.parse.urlencode({
        "q": f"{city_name}, {country}",
        "format": "json",
        "limit": 1,
        "addressdetails": 0,
    })
    url = f"{NOMINATIM_URL}?{params}"
    req = urllib.request.Request(url, headers=HEADERS)
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            results = json.loads(resp.read())
            if results:
                return float(results[0]["lat"]), float(results[0]["lon"])
    except Exception as e:
        print(f"    ⚠️  Error geocoding {city_name}: {e}")
    return None


def load_cache():
    if os.path.exists(CACHE_FILE):
        with open(CACHE_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    return {}


def save_cache(data):
    with open(CACHE_FILE, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)


def distribute():
    script = os.path.join(os.path.dirname(__file__), "distribute-caches.sh")
    if os.path.exists(script):
        print("\n📦 Distributing caches to all platforms...")
        result = subprocess.run(["bash", script], capture_output=True, text=True,
                                cwd=os.path.dirname(__file__))
        print(result.stdout)
        if result.returncode != 0:
            print("⚠️  Distribution errors:", result.stderr)
    else:
        print(f"⚠️  distribute-caches.sh not found at {script}")


def main():
    cache = load_cache()
    existing_countries = set(cache.keys())
    new_countries = {k: v for k, v in NEW_COUNTRIES.items() if k not in existing_countries}

    print(f"📋 Existing countries: {len(existing_countries)}")
    print(f"🌍 New countries to add: {len(new_countries)}")
    if not new_countries:
        print("✅ Nothing to do — all countries already present.")
        return

    total_new = 0
    for idx, (country, city_names) in enumerate(new_countries.items(), 1):
        print(f"\n[{idx}/{len(new_countries)}] {country} — {len(city_names)} cities to geocode")
        if country not in cache:
            cache[country] = []

        existing_names = {c["name"].lower() for c in cache[country]}
        to_add = [c for c in city_names if c.lower() not in existing_names]
        added = 0

        for city in to_add:
            result = geocode_city(city, country)
            time.sleep(1.1)  # Nominatim rate limit: 1 req/sec
            if result:
                lat, lon = result
                cache[country].append({
                    "name": city,
                    "country": country,
                    "lat": lat,
                    "lon": lon,
                })
                added += 1
                print(f"    ✓ {city} ({lat:.4f}, {lon:.4f})")
            else:
                print(f"    ✗ {city} — not found")

        print(f"  → {added}/{len(to_add)} cities added for {country}")
        total_new += added

        # Save after every country
        save_cache(cache)
        print(f"  💾 Saved ({sum(len(v) for v in cache.values())} cities total)")

        # Brief pause between countries
        if idx < len(new_countries):
            time.sleep(3)

    total_countries = len(cache)
    total_cities = sum(len(v) for v in cache.values())
    print(f"\n✅ Expansion complete! {total_countries} countries, {total_cities} total cities.")
    print(f"   Added {total_new} new cities across {len(new_countries)} new countries.")

    distribute()
    print("\n✅ Distribution complete!")


if __name__ == "__main__":
    main()
