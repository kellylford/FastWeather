/**
 * International Cities Data
 * Contains major cities for various countries
 */

const INTERNATIONAL_CITIES_BY_COUNTRY = {
    "Argentina": [
        "Buenos Aires", "Córdoba", "Rosario", "Mendoza", "La Plata",
        "San Miguel de Tucumán", "Mar del Plata", "Salta", "Santa Fe", "San Juan",
        "Resistencia", "Santiago del Estero", "Corrientes", "Posadas", "Bahía Blanca",
        "Paraná", "Neuquén", "Formosa", "San Salvador de Jujuy", "La Rioja"
    ],
    "Australia": [
        "Sydney", "Melbourne", "Brisbane", "Perth", "Adelaide",
        "Gold Coast", "Newcastle", "Canberra", "Wollongong", "Hobart",
        "Geelong", "Townsville", "Cairns", "Darwin", "Toowoomba",
        "Ballarat", "Bendigo", "Albury", "Launceston", "Mackay"
    ],
    "Austria": [
        "Vienna", "Graz", "Linz", "Salzburg", "Innsbruck",
        "Klagenfurt", "Villach", "Wels", "Sankt Pölten", "Dornbirn",
        "Wiener Neustadt", "Steyr", "Feldkirch", "Bregenz", "Leonding",
        "Klosterneuburg", "Baden", "Wolfsberg", "Leoben", "Krems"
    ],
    "Belgium": [
        "Brussels", "Antwerp", "Ghent", "Charleroi", "Liège",
        "Bruges", "Namur", "Leuven", "Mons", "Mechelen",
        "Aalst", "La Louvière", "Kortrijk", "Hasselt", "Sint-Niklaas",
        "Ostend", "Genk", "Seraing", "Roeselare", "Verviers"
    ],
    "Brazil": [
        "São Paulo", "Rio de Janeiro", "Brasília", "Salvador", "Fortaleza",
        "Belo Horizonte", "Manaus", "Curitiba", "Recife", "Porto Alegre",
        "Belém", "Goiânia", "Guarulhos", "Campinas", "São Luís",
        "São Gonçalo", "Maceió", "Duque de Caxias", "Natal", "Campo Grande"
    ],
    "Canada": [
        "Toronto", "Montreal", "Vancouver", "Calgary", "Edmonton",
        "Ottawa", "Winnipeg", "Quebec City", "Hamilton", "Kitchener",
        "London", "Victoria", "Halifax", "Oshawa", "Windsor",
        "Saskatoon", "Regina", "St. Catharines", "Barrie", "Kelowna"
    ],
    "China": [
        "Beijing", "Shanghai", "Guangzhou", "Shenzhen", "Chengdu",
        "Tianjin", "Wuhan", "Dongguan", "Chongqing", "Nanjing",
        "Shenyang", "Hangzhou", "Xi'an", "Harbin", "Suzhou",
        "Qingdao", "Dalian", "Zhengzhou", "Changsha", "Kunming"
    ],
    "Denmark": [
        "Copenhagen", "Aarhus", "Odense", "Aalborg", "Esbjerg",
        "Randers", "Kolding", "Horsens", "Vejle", "Roskilde",
        "Herning", "Silkeborg", "Næstved", "Fredericia", "Viborg",
        "Køge", "Holstebro", "Taastrup", "Slagelse", "Hillerød"
    ],
    "Finland": [
        "Helsinki", "Espoo", "Tampere", "Vantaa", "Oulu",
        "Turku", "Jyväskylä", "Lahti", "Kuopio", "Pori",
        "Joensuu", "Lappeenranta", "Hämeenlinna", "Vaasa", "Rovaniemi",
        "Seinäjoki", "Mikkeli", "Kotka", "Salo", "Porvoo"
    ],
    "France": [
        "Paris", "Marseille", "Lyon", "Toulouse", "Nice",
        "Nantes", "Strasbourg", "Montpellier", "Bordeaux", "Lille",
        "Rennes", "Reims", "Le Havre", "Saint-Étienne", "Toulon",
        "Grenoble", "Dijon", "Angers", "Nîmes", "Villeurbanne"
    ],
    "Germany": [
        "Berlin", "Hamburg", "Munich", "Cologne", "Frankfurt",
        "Stuttgart", "Düsseldorf", "Dortmund", "Essen", "Leipzig",
        "Bremen", "Dresden", "Hanover", "Nuremberg", "Duisburg",
        "Bochum", "Wuppertal", "Bielefeld", "Bonn", "Münster"
    ],
    "India": [
        "Mumbai", "Delhi", "Bangalore", "Hyderabad", "Chennai",
        "Kolkata", "Pune", "Ahmedabad", "Surat", "Jaipur",
        "Lucknow", "Kanpur", "Nagpur", "Indore", "Thane",
        "Bhopal", "Visakhapatnam", "Pimpri-Chinchwad", "Patna", "Vadodara"
    ],
    "Ireland": [
        "Dublin", "Cork", "Limerick", "Galway", "Waterford",
        "Drogheda", "Dundalk", "Swords", "Bray", "Navan",
        "Ennis", "Kilkenny", "Carlow", "Tralee", "Newbridge",
        "Naas", "Sligo", "Mullingar", "Wexford", "Letterkenny"
    ],
    "Italy": [
        "Rome", "Milan", "Naples", "Turin", "Palermo",
        "Genoa", "Bologna", "Florence", "Bari", "Catania",
        "Venice", "Verona", "Messina", "Padua", "Trieste",
        "Brescia", "Taranto", "Prato", "Reggio Calabria", "Modena"
    ],
    "Japan": [
        "Tokyo", "Yokohama", "Osaka", "Nagoya", "Sapporo",
        "Fukuoka", "Kobe", "Kyoto", "Kawasaki", "Saitama",
        "Hiroshima", "Sendai", "Kitakyushu", "Chiba", "Sakai",
        "Niigata", "Hamamatsu", "Kumamoto", "Sagamihara", "Shizuoka"
    ],
    "Mexico": [
        "Mexico City", "Guadalajara", "Monterrey", "Puebla", "Tijuana",
        "León", "Juárez", "Zapopan", "Mérida", "San Luis Potosí",
        "Aguascalientes", "Hermosillo", "Saltillo", "Mexicali", "Culiacán",
        "Querétaro", "Chihuahua", "Morelia", "Toluca", "Cancún"
    ],
    "Netherlands": [
        "Amsterdam", "Rotterdam", "The Hague", "Utrecht", "Eindhoven",
        "Tilburg", "Groningen", "Almere", "Breda", "Nijmegen",
        "Enschede", "Haarlem", "Arnhem", "Zaanstad", "Amersfoort",
        "Apeldoorn", "Hoofddorp", "Maastricht", "Leiden", "Dordrecht"
    ],
    "New Zealand": [
        "Auckland", "Wellington", "Christchurch", "Hamilton", "Tauranga",
        "Dunedin", "Palmerston North", "Napier", "Porirua", "Hibiscus Coast",
        "New Plymouth", "Rotorua", "Whangarei", "Nelson", "Hastings",
        "Invercargill", "Upper Hutt", "Gisborne", "Taupo", "Blenheim"
    ],
    "Norway": [
        "Oslo", "Bergen", "Stavanger", "Trondheim", "Drammen",
        "Fredrikstad", "Kristiansand", "Sandnes", "Tromsø", "Sarpsborg",
        "Skien", "Ålesund", "Sandefjord", "Haugesund", "Tønsberg",
        "Moss", "Porsgrunn", "Bodø", "Arendal", "Hamar"
    ],
    "Poland": [
        "Warsaw", "Kraków", "Łódź", "Wrocław", "Poznań",
        "Gdańsk", "Szczecin", "Bydgoszcz", "Lublin", "Katowice",
        "Białystok", "Gdynia", "Częstochowa", "Radom", "Sosnowiec",
        "Toruń", "Kielce", "Gliwice", "Zabrze", "Bytom"
    ],
    "South Korea": [
        "Seoul", "Busan", "Incheon", "Daegu", "Daejeon",
        "Gwangju", "Suwon", "Ulsan", "Changwon", "Seongnam",
        "Goyang", "Yongin", "Bucheon", "Cheongju", "Ansan",
        "Jeonju", "Cheonan", "Pohang", "Gimhae", "Jeju City"
    ],
    "Spain": [
        "Madrid", "Barcelona", "Valencia", "Seville", "Zaragoza",
        "Málaga", "Murcia", "Palma", "Las Palmas", "Bilbao",
        "Alicante", "Córdoba", "Valladolid", "Vigo", "Gijón",
        "Hospitalet de Llobregat", "A Coruña", "Granada", "Vitoria-Gasteiz", "Elche"
    ],
    "Sweden": [
        "Stockholm", "Gothenburg", "Malmö", "Uppsala", "Västerås",
        "Örebro", "Linköping", "Helsingborg", "Jönköping", "Norrköping",
        "Lund", "Umeå", "Gävle", "Borås", "Södertälje",
        "Eskilstuna", "Halmstad", "Växjö", "Karlstad", "Sundsvall"
    ],
    "Switzerland": [
        "Zürich", "Geneva", "Basel", "Lausanne", "Bern",
        "Winterthur", "Lucerne", "St. Gallen", "Lugano", "Biel/Bienne",
        "Thun", "Köniz", "La Chaux-de-Fonds", "Schaffhausen", "Fribourg",
        "Vernier", "Chur", "Neuchâtel", "Uster", "Sion"
    ],
    "United Kingdom": [
        "London", "Birmingham", "Manchester", "Glasgow", "Liverpool",
        "Leeds", "Sheffield", "Edinburgh", "Bristol", "Cardiff",
        "Leicester", "Bradford", "Belfast", "Nottingham", "Newcastle",
        "Southampton", "Portsmouth", "Plymouth", "Stoke-on-Trent", "Wolverhampton"
    ],
    "Bangladesh": [
        "Dhaka", "Chittagong", "Khulna", "Rajshahi", "Sylhet",
        "Barisal", "Rangpur", "Mymensingh", "Comilla", "Narayanganj",
        "Gazipur", "Brahmanbaria", "Tongi", "Cox's Bazar", "Jessore",
        "Bogra", "Dinajpur", "Pabna", "Kushtia", "Jamalpur"
    ],
    "Egypt": [
        "Cairo", "Alexandria", "Giza", "Shubra El Kheima", "Port Said",
        "Suez", "Luxor", "Mansoura", "Tanta", "Asyut",
        "Ismailia", "Faiyum", "Zagazig", "Aswan", "Damietta",
        "Minya", "Damanhur", "Beni Suef", "Hurghada", "Qena"
    ],
    "Ethiopia": [
        "Addis Ababa", "Dire Dawa", "Mekelle", "Gondar", "Hawassa",
        "Bahir Dar", "Jimma", "Dessie", "Harar", "Sodo",
        "Arba Minch", "Nekemte", "Adama", "Jijiga", "Debre Markos",
        "Shashemene", "Dilla", "Hosaena", "Adigrat", "Debre Birhan"
    ],
    "Indonesia": [
        "Jakarta", "Surabaya", "Bandung", "Medan", "Semarang",
        "Makassar", "Palembang", "Tangerang", "Depok", "Bekasi",
        "South Tangerang", "Bogor", "Batam", "Pekanbaru", "Bandar Lampung",
        "Padang", "Malang", "Denpasar", "Samarinda", "Balikpapan"
    ],
    "Kenya": [
        "Nairobi", "Mombasa", "Kisumu", "Nakuru", "Eldoret",
        "Ruiru", "Kikuyu", "Thika", "Malindi", "Kitale",
        "Garissa", "Kakamega", "Nyeri", "Meru", "Machakos",
        "Naivasha", "Voi", "Kisii", "Kitui", "Lamu"
    ],
    "Malaysia": [
        "Kuala Lumpur", "George Town", "Ipoh", "Shah Alam", "Petaling Jaya",
        "Johor Bahru", "Malacca City", "Alor Setar", "Seremban", "Kuching",
        "Kota Kinabalu", "Kuala Terengganu", "Kuantan", "Klang", "Iskandar Puteri",
        "Sandakan", "Taiping", "Bintulu", "Miri", "Sibu"
    ],
    "Morocco": [
        "Casablanca", "Rabat", "Fes", "Marrakesh", "Tangier",
        "Salé", "Meknes", "Oujda", "Kenitra", "Agadir",
        "Tetouan", "Temara", "Safi", "Mohammedia", "Khouribga",
        "El Jadida", "Beni Mellal", "Nador", "Taza", "Settat"
    ],
    "Nigeria": [
        "Lagos", "Kano", "Ibadan", "Abuja", "Port Harcourt",
        "Benin City", "Kaduna", "Maiduguri", "Zaria", "Aba",
        "Jos", "Ilorin", "Oyo", "Enugu", "Abeokuta",
        "Onitsha", "Warri", "Sokoto", "Calabar", "Akure"
    ],
    "Pakistan": [
        "Karachi", "Lahore", "Faisalabad", "Rawalpindi", "Multan",
        "Hyderabad", "Gujranwala", "Peshawar", "Quetta", "Islamabad",
        "Bahawalpur", "Sargodha", "Sialkot", "Sukkur", "Larkana",
        "Sheikhupura", "Jhang", "Rahim Yar Khan", "Gujrat", "Mardan"
    ],
    "Philippines": [
        "Manila", "Quezon City", "Davao City", "Caloocan", "Cebu City",
        "Zamboanga City", "Taguig", "Antipolo", "Pasig", "Cagayan de Oro",
        "Parañaque", "Valenzuela", "Las Piñas", "Makati", "Dasmarinas",
        "Bacoor", "General Santos", "Muntinlupa", "Marikina", "Iloilo City"
    ],
    "Singapore": [
        "Singapore", "Woodlands", "Tampines", "Jurong West", "Bedok",
        "Hougang", "Yishun", "Ang Mo Kio", "Bukit Batok", "Choa Chu Kang",
        "Punggol", "Sengkang", "Bishan", "Toa Payoh", "Clementi",
        "Pasir Ris", "Bukit Panjang", "Serangoon", "Kallang", "Geylang"
    ],
    "South Africa": [
        "Johannesburg", "Cape Town", "Durban", "Pretoria", "Port Elizabeth",
        "Bloemfontein", "East London", "Polokwane", "Pietermaritzburg", "Nelspruit",
        "Kimberley", "Rustenburg", "George", "Soweto", "Midrand",
        "Benoni", "Boksburg", "Vanderbijlpark", "Krugersdorp", "Vereeniging"
    ],
    "Taiwan": [
        "Taipei", "Kaohsiung", "Taichung", "Tainan", "Taoyuan",
        "Hsinchu", "Keelung", "Chiayi", "Changhua", "Zhongli",
        "Pingtung", "Yilan", "Hualien", "Taitung", "Miaoli",
        "Douliu", "Nantou", "Magong", "Jincheng", "Matsu"
    ],
    "Thailand": [
        "Bangkok", "Chiang Mai", "Nakhon Ratchasima", "Hat Yai", "Udon Thani",
        "Surat Thani", "Khon Kaen", "Nakhon Si Thammarat", "Chiang Rai", "Lampang",
        "Phuket", "Nakhon Sawan", "Ubon Ratchathani", "Sakon Nakhon", "Phitsanulok",
        "Rayong", "Pattaya", "Krabi", "Songkhla", "Nonthaburi"
    ],
    "Turkey": [
        "Istanbul", "Ankara", "Izmir", "Bursa", "Adana",
        "Gaziantep", "Konya", "Antalya", "Kayseri", "Mersin",
        "Diyarbakır", "Eskişehir", "Samsun", "Denizli", "Şanlıurfa",
        "Adapazarı", "Malatya", "Kahramanmaraş", "Erzurum", "Van"
    ],
    "Vietnam": [
        "Ho Chi Minh City", "Hanoi", "Da Nang", "Hai Phong", "Can Tho",
        "Bien Hoa", "Hue", "Nha Trang", "Buon Ma Thuot", "Vung Tau",
        "Phan Thiet", "Rach Gia", "Quy Nhon", "Long Xuyen", "My Tho",
        "Nam Dinh", "Thai Nguyen", "Thanh Hoa", "Vinh", "Da Lat"
    ]
};
