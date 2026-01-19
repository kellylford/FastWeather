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
    "Greenland": [
        "Nuuk", "Sisimiut", "Ilulissat", "Qaqortoq", "Aasiaat",
        "Maniitsoq", "Tasiilaq", "Narsaq", "Paamiut", "Nanortalik",
        "Uummannaq", "Upernavik", "Qeqertarsuaq", "Qaanaaq", "Ittoqqortoormiit",
        "Kangaatsiaq", "Kullorsuaq", "Qaarsut", "Saattut", "Kangerlussuaq"
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
    ],
    "Russia": [
        "Moscow", "Saint Petersburg", "Novosibirsk", "Yekaterinburg", "Kazan",
        "Nizhny Novgorod", "Chelyabinsk", "Samara", "Omsk", "Rostov-on-Don",
        "Ufa", "Krasnoyarsk", "Voronezh", "Perm", "Volgograd",
        "Krasnodar", "Saratov", "Tyumen", "Tolyatti", "Izhevsk"
    ],
    "Ukraine": [
        "Kyiv", "Kharkiv", "Odesa", "Dnipro", "Donetsk",
        "Zaporizhzhia", "Lviv", "Kryvyi Rih", "Mykolaiv", "Mariupol",
        "Luhansk", "Vinnytsia", "Simferopol", "Makiivka", "Sevastopol",
        "Chernihiv", "Poltava", "Kherson", "Khmelnytskyi", "Cherkasy"
    ],
    "Saudi Arabia": [
        "Riyadh", "Jeddah", "Mecca", "Medina", "Dammam",
        "Khobar", "Tabuk", "Buraidah", "Khamis Mushait", "Hofuf",
        "Taif", "Najran", "Jubail", "Abha", "Yanbu",
        "Al Qatif", "Sakakah", "Jizan", "Arar", "Hail"
    ],
    "United Arab Emirates": [
        "Dubai", "Abu Dhabi", "Sharjah", "Al Ain", "Ajman",
        "Ras Al Khaimah", "Fujairah", "Umm Al Quwain", "Khor Fakkan", "Dibba Al-Fujairah",
        "Dhaid", "Jebel Ali", "Ruwais", "Madinat Zayed", "Liwa Oasis",
        "Kalba", "Ghayathi", "Al Dhafra", "Sweihan", "Al Sila"
    ],
    "Israel": [
        "Jerusalem", "Tel Aviv", "Haifa", "Rishon LeZion", "Petah Tikva",
        "Ashdod", "Netanya", "Beersheba", "Holon", "Bnei Brak",
        "Ramat Gan", "Ashkelon", "Rehovot", "Bat Yam", "Beit Shemesh",
        "Herzliya", "Kfar Saba", "Hadera", "Modiin", "Nazareth"
    ],
    "Iraq": [
        "Baghdad", "Basra", "Mosul", "Erbil", "Kirkuk",
        "Najaf", "Karbala", "Sulaymaniyah", "Nasiriyah", "Amarah",
        "Duhok", "Kut", "Ramadi", "Hillah", "Samarra",
        "Diwaniyah", "Tikrit", "Baqubah", "Fallujah", "Zakho"
    ],
    "Iran": [
        "Tehran", "Mashhad", "Isfahan", "Karaj", "Shiraz",
        "Tabriz", "Qom", "Ahvaz", "Kermanshah", "Urmia",
        "Rasht", "Zahedan", "Hamadan", "Yazd", "Ardabil",
        "Bandar Abbas", "Arak", "Eslamshahr", "Zanjan", "Sanandaj"
    ],
    "Jordan": [
        "Amman", "Zarqa", "Irbid", "Russeifa", "Aqaba",
        "Madaba", "Sahab", "Mafraq", "Jerash", "Ajloun",
        "Karak", "Salt", "Tafilah", "Ma'an", "Ramtha",
        "Azraq", "Petra", "Wadi Musa", "Umm Qais", "Fuheis"
    ],
    "Qatar": [
        "Doha", "Al Rayyan", "Umm Salal", "Al Wakrah", "Al Khor",
        "Mesaieed", "Dukhan", "Al Shamal", "Madinat ash Shamal", "Al Ghuwariyah",
        "Simaisma", "Al Jumailiyah", "Al Wukair", "Al Khawr", "Lusail",
        "Al Daayen", "Al Shahaniya", "Fuwayrit", "Rawdat Rashed", "Umm Bab"
    ],
    "Kuwait": [
        "Kuwait City", "Hawalli", "Salmiya", "Jabriya", "Farwaniya",
        "Ahmadi", "Sabah Al Salem", "Fahaheel", "Mangaf", "Fintas",
        "Mahboula", "Jahra", "Salwa", "Bayan", "Mishref",
        "Rumaithiya", "Abdullah Al-Mubarak", "Jleeb Al-Shuyoukh", "Khaitan", "Ardiya"
    ],
    "Colombia": [
        "Bogotá", "Medellín", "Cali", "Barranquilla", "Cartagena",
        "Cúcuta", "Bucaramanga", "Pereira", "Santa Marta", "Ibagué",
        "Pasto", "Manizales", "Neiva", "Villavicencio", "Armenia",
        "Valledupar", "Montería", "Popayán", "Buenaventura", "Palmira"
    ],
    "Peru": [
        "Lima", "Arequipa", "Trujillo", "Chiclayo", "Piura",
        "Iquitos", "Cusco", "Huancayo", "Chimbote", "Tacna",
        "Juliaca", "Ica", "Sullana", "Ayacucho", "Cajamarca",
        "Pucallpa", "Huánuco", "Tarapoto", "Chincha Alta", "Huaraz"
    ],
    "Chile": [
        "Santiago", "Valparaíso", "Concepción", "La Serena", "Antofagasta",
        "Temuco", "Rancagua", "Talca", "Arica", "Chillán",
        "Iquique", "Los Ángeles", "Puerto Montt", "Coquimbo", "Osorno",
        "Valdivia", "Punta Arenas", "Copiapó", "Quilpué", "Curicó"
    ],
    "Greece": [
        "Athens", "Thessaloniki", "Patras", "Heraklion", "Larissa",
        "Volos", "Rhodes", "Ioannina", "Chania", "Agrinio",
        "Katerini", "Kalamata", "Kavala", "Serres", "Chalcis",
        "Lamia", "Komotini", "Kozani", "Alexandroupoli", "Veria"
    ],
    "Portugal": [
        "Lisbon", "Porto", "Vila Nova de Gaia", "Amadora", "Braga",
        "Funchal", "Coimbra", "Setúbal", "Almada", "Agualva-Cacém",
        "Queluz", "Rio de Mouro", "Corroios", "Barreiro", "Évora",
        "Faro", "Aveiro", "Viseu", "Guimarães", "Leiria"
    ],
    "Czech Republic": [
        "Prague", "Brno", "Ostrava", "Plzeň", "Liberec",
        "Olomouc", "České Budějovice", "Hradec Králové", "Ústí nad Labem", "Pardubice",
        "Zlín", "Havířov", "Kladno", "Most", "Opava",
        "Frýdek-Místek", "Jihlava", "Teplice", "Karviná", "Děčín"
    ],
    "Hungary": [
        "Budapest", "Debrecen", "Szeged", "Miskolc", "Pécs",
        "Győr", "Nyíregyháza", "Kecskemét", "Székesfehérvár", "Szombathely",
        "Szolnok", "Tatabánya", "Kaposvár", "Érd", "Veszprém",
        "Zalaegerszeg", "Sopron", "Eger", "Nagykanizsa", "Dunakeszi"
    ],
    "Romania": [
        "Bucharest", "Cluj-Napoca", "Timișoara", "Iași", "Constanța",
        "Craiova", "Brașov", "Galați", "Ploiești", "Oradea",
        "Brăila", "Arad", "Pitești", "Sibiu", "Bacău",
        "Târgu Mureș", "Baia Mare", "Buzău", "Botoșani", "Satu Mare"
    ],
    "Venezuela": [
        "Caracas", "Maracaibo", "Valencia", "Barquisimeto", "Maracay",
        "Ciudad Guayana", "Barcelona", "Maturín", "Puerto La Cruz", "Petare",
        "Turmero", "Ciudad Bolívar", "Mérida", "Santa Teresa del Tuy", "Cumaná",
        "San Cristóbal", "Cabimas", "Barinas", "Guatire", "Los Teques"
    ],
    "Kazakhstan": [
        "Almaty", "Astana", "Shymkent", "Karaganda", "Aktobe",
        "Taraz", "Pavlodar", "Ust-Kamenogorsk", "Semey", "Atyrau",
        "Kostanay", "Kyzylorda", "Oral", "Petropavl", "Aktau",
        "Temirtau", "Turkistan", "Kokshetau", "Rudny", "Ekibastuz"
    ],
    "Ecuador": [
        "Quito", "Guayaquil", "Cuenca", "Santo Domingo", "Machala",
        "Durán", "Manta", "Portoviejo", "Loja", "Ambato",
        "Esmeraldas", "Quevedo", "Riobamba", "Milagro", "Ibarra",
        "La Libertad", "Babahoyo", "Sangolquí", "Latacunga", "Daule"
    ],
    "Bolivia": [
        "Santa Cruz de la Sierra", "La Paz", "El Alto", "Cochabamba", "Sucre",
        "Oruro", "Tarija", "Potosí", "Sacaba", "Montero",
        "Trinidad", "Yacuiba", "Riberalta", "Quillacollo", "Warnes",
        "Cobija", "Villamontes", "Guayaramerín", "Bermejo", "Camiri"
    ],
    "Uruguay": [
        "Montevideo", "Salto", "Ciudad de la Costa", "Paysandú", "Las Piedras",
        "Rivera", "Maldonado", "Tacuarembó", "Melo", "Mercedes",
        "Artigas", "Minas", "San José de Mayo", "Durazno", "Florida",
        "Treinta y Tres", "Rocha", "Colonia del Sacramento", "Fray Bentos", "Carmelo"
    ],
    "Paraguay": [
        "Asunción", "Ciudad del Este", "San Lorenzo", "Luque", "Capiatá",
        "Lambaré", "Fernando de la Mora", "Limpio", "Ñemby", "Encarnación",
        "Mariano Roque Alonso", "Pedro Juan Caballero", "Itauguá", "Villa Elisa", "Caaguazú",
        "Villarrica", "Coronel Oviedo", "Concepción", "Presidente Franco", "San Antonio"
    ],
    "Dominican Republic": [
        "Santo Domingo", "Santiago de los Caballeros", "La Romana", "San Pedro de Macorís", "San Cristóbal",
        "Puerto Plata", "San Francisco de Macorís", "La Vega", "Higüey", "Concepción de La Vega",
        "Moca", "Boca Chica", "Baní", "Bonao", "San Juan de la Maguana",
        "Cotuí", "Azua", "Hato Mayor", "Nagua", "Mao"
    ],
    "Panama": [
        "Panama City", "San Miguelito", "Tocumen", "David", "Arraiján",
        "Colón", "Las Cumbres", "La Chorrera", "Pacora", "Santiago",
        "Chitré", "Penonomé", "La Concepción", "Aguadulce", "Changuinola",
        "Vista Alegre", "Alcalde Díaz", "Bugaba", "Los Santos", "Pedregal"
    ],
    "Costa Rica": [
        "San José", "Limón", "Alajuela", "Heredia", "Cartago",
        "Puntarenas", "Liberia", "Paraíso", "Pococí", "San Vicente",
        "San Isidro", "Curridabat", "San Carlos", "Desamparados", "Purral",
        "San Felipe", "Pérez Zeledón", "Escazú", "Guadalupe", "Ipís"
    ],
    "Guatemala": [
        "Guatemala City", "Mixco", "Villa Nueva", "Petapa", "San Juan Sacatepéquez",
        "Quetzaltenango", "Villa Canales", "Escuintla", "Chinautla", "Chimaltenango",
        "Huehuetenango", "Amatitlán", "Totonicapán", "Santa Lucía Cotzumalguapa", "Cobán",
        "Puerto Barrios", "San Marcos", "Jalapa", "Jutiapa", "Chichicastenango"
    ],
    "El Salvador": [
        "San Salvador", "Soyapango", "Santa Ana", "San Miguel", "Mejicanos",
        "Delgado", "Apopa", "Ilopango", "Cuscatancingo", "Usulután",
        "Ahuachapán", "La Libertad", "Zacatecoluca", "Sonsonate", "San Martín",
        "Cojutepeque", "Chalatenango", "La Unión", "Sensuntepeque", "Metapán"
    ],
    "Honduras": [
        "Tegucigalpa", "San Pedro Sula", "Choloma", "La Ceiba", "El Progreso",
        "Villanueva", "Choluteca", "Comayagua", "Puerto Cortés", "La Lima",
        "Danlí", "Siguatepeque", "Juticalpa", "Tocoa", "Tela",
        "Santa Rosa de Copán", "Olanchito", "Catacamas", "Cofradía", "Potrerillos"
    ],
    "Croatia": [
        "Zagreb", "Split", "Rijeka", "Osijek", "Zadar",
        "Slavonski Brod", "Pula", "Sesvete", "Karlovac", "Varaždin",
        "Šibenik", "Sisak", "Dubrovnik", "Bjelovar", "Velika Gorica",
        "Vinkovci", "Vukovar", "Samobor", "Koprivnica", "Zaprešić"
    ],
    "Serbia": [
        "Belgrade", "Novi Sad", "Niš", "Kragujevac", "Subotica",
        "Zrenjanin", "Pančevo", "Čačak", "Novi Pazar", "Kruševac",
        "Leskovac", "Kraljevo", "Smederevo", "Valjevo", "Šabac",
        "Užice", "Sombor", "Požarevac", "Pirot", "Zaječar"
    ],
    "Bulgaria": [
        "Sofia", "Plovdiv", "Varna", "Burgas", "Ruse",
        "Stara Zagora", "Pleven", "Sliven", "Dobrich", "Shumen",
        "Pernik", "Haskovo", "Yambol", "Pazardzhik", "Blagoevgrad",
        "Veliko Tarnovo", "Vratsa", "Gabrovo", "Asenovgrad", "Vidin"
    ],
    "Slovakia": [
        "Bratislava", "Košice", "Prešov", "Žilina", "Nitra",
        "Banská Bystrica", "Trnava", "Martin", "Trenčín", "Poprad",
        "Prievidza", "Zvolen", "Považská Bystrica", "Michalovce", "Spišská Nová Ves",
        "Komárno", "Levice", "Humenné", "Bardejov", "Liptovský Mikuláš"
    ],
    "Slovenia": [
        "Ljubljana", "Maribor", "Celje", "Kranj", "Velenje",
        "Koper", "Novo Mesto", "Ptuj", "Trbovlje", "Kamnik",
        "Jesenice", "Nova Gorica", "Domžale", "Škofja Loka", "Slovenj Gradec",
        "Izola", "Postojna", "Murska Sobota", "Krško", "Ajdovščina"
    ],
    "Algeria": [
        "Algiers", "Oran", "Constantine", "Batna", "Djelfa",
        "Sétif", "Annaba", "Sidi Bel Abbès", "Biskra", "Tébessa",
        "El Eulma", "Skikda", "Tiaret", "Béjaïa", "Tlemcen",
        "Bordj Bou Arréridj", "Béchar", "Blida", "Mostaganem", "Tizi Ouzou"
    ],
    "Tunisia": [
        "Tunis", "Sfax", "Sousse", "Kairouan", "Bizerte",
        "Gabès", "Ariana", "Gafsa", "Monastir", "Ben Arous",
        "Kasserine", "Médenine", "Nabeul", "Tataouine", "Béja",
        "Jendouba", "Mahdia", "Siliana", "Kef", "Tozeur"
    ],
    "Ghana": [
        "Accra", "Kumasi", "Tamale", "Sekondi-Takoradi", "Ashaiman",
        "Sunyani", "Cape Coast", "Obuasi", "Teshie", "Tema",
        "Madina", "Koforidua", "Wa", "Techiman", "Ho",
        "Nungua", "Lashibi", "Dome", "Gbawe", "Ejura"
    ],
    "Tanzania": [
        "Dar es Salaam", "Mwanza", "Arusha", "Dodoma", "Mbeya",
        "Morogoro", "Tanga", "Kahama", "Tabora", "Zanzibar City",
        "Kigoma", "Sumbawanga", "Kasulu", "Songea", "Moshi",
        "Musoma", "Shinyanga", "Iringa", "Singida", "Njombe"
    ],
    "Uganda": [
        "Kampala", "Nansana", "Kira", "Ssabagabo", "Mbarara",
        "Mukono", "Gulu", "Kasese", "Masaka", "Entebbe",
        "Lira", "Jinja", "Hoima", "Soroti", "Mbale",
        "Arua", "Kabale", "Fort Portal", "Mityana", "Lugazi"
    ],
    "Cameroon": [
        "Douala", "Yaoundé", "Bamenda", "Bafoussam", "Garoua",
        "Kousseri", "Maroua", "Ngaoundéré", "Bertoua", "Loum",
        "Kumba", "Nkongsamba", "Buea", "Mbouda", "Foumban",
        "Dschang", "Limbé", "Ebolowa", "Kribi", "Edéa"
    ],
    "Senegal": [
        "Dakar", "Pikine", "Touba", "Thiès", "Kaolack",
        "Saint-Louis", "Mbour", "Ziguinchor", "Rufisque", "Diourbel",
        "Louga", "Tambacounda", "Kolda", "Richard Toll", "Matam",
        "Sédhiou", "Mbacké", "Tivaouane", "Guédiawaye", "Fatick"
    ],
    "Côte d'Ivoire": [
        "Abidjan", "Bouaké", "Daloa", "San-Pédro", "Yamoussoukro",
        "Korhogo", "Man", "Divo", "Gagnoa", "Abengourou",
        "Anyama", "Agboville", "Grand-Bassam", "Dabou", "Bondoukou",
        "Soubré", "Oumé", "Séguéla", "Bingerville", "Issia"
    ],
    "Zimbabwe": [
        "Harare", "Bulawayo", "Chitungwiza", "Mutare", "Gweru",
        "Epworth", "Kwekwe", "Kadoma", "Masvingo", "Chinhoyi",
        "Norton", "Marondera", "Ruwa", "Chegutu", "Zvishavane",
        "Bindura", "Beitbridge", "Redcliff", "Victoria Falls", "Hwange"
    ],
    "Mozambique": [
        "Maputo", "Matola", "Nampula", "Beira", "Chimoio",
        "Nacala", "Quelimane", "Tete", "Lichinga", "Pemba",
        "Inhambane", "Xai-Xai", "Maxixe", "Angoche", "Cuamba",
        "Montepuez", "Mocuba", "Gurué", "Dondo", "Chibuto"
    ],
    "Angola": [
        "Luanda", "Huambo", "Lobito", "Benguela", "Lubango",
        "Kuito", "Malanje", "Namibe", "Soyo", "Cabinda",
        "Uíge", "Saurimo", "Luena", "Menongue", "Sumbe",
        "N'dalatando", "Ondjiva", "Caxito", "Camacupa", "Lucapa"
    ],
    "Jamaica": [
        "Kingston", "Spanish Town", "Portmore", "Montego Bay", "May Pen",
        "Mandeville", "Old Harbour", "Savanna-la-Mar", "Port Antonio", "Saint Ann's Bay",
        "Linstead", "Half Way Tree", "Constant Spring", "Morant Bay", "Ocho Rios",
        "Bog Walk", "Ewarton", "Hayes", "Port Maria", "Santa Cruz"
    ],
    "Trinidad and Tobago": [
        "Port of Spain", "Chaguanas", "San Fernando", "Arima", "Marabella",
        "Point Fortin", "Tunapuna", "Saint Joseph", "Sangre Grande", "Princes Town",
        "Diego Martin", "Couva", "Scarborough", "Penal", "Siparia",
        "D'Abadie", "Debe", "Arouca", "Curepe", "Fyzabad"
    ],
    "Cuba": [
        "Havana", "Santiago de Cuba", "Camagüey", "Holguín", "Guantánamo",
        "Santa Clara", "Las Tunas", "Bayamo", "Cienfuegos", "Pinar del Río",
        "Matanzas", "Ciego de Ávila", "Sancti Spíritus", "Manzanillo", "Cárdenas",
        "Palma Soriano", "Nuevitas", "Artemisa", "Contramaestre", "Morón"
    ],
    "Cambodia": [
        "Phnom Penh", "Siem Reap", "Battambang", "Sihanoukville", "Poipet",
        "Kampong Cham", "Prey Veng", "Ta Khmau", "Pursat", "Kampong Speu",
        "Kampong Chhnang", "Sisophon", "Kratié", "Stung Treng", "Kampot",
        "Kep", "Pailin", "Koh Kong", "Bavet", "Svay Rieng"
    ],
    "Laos": [
        "Vientiane", "Pakse", "Savannakhet", "Luang Prabang", "Thakhek",
        "Xam Neua", "Phonsavan", "Vang Vieng", "Muang Xay", "Salavan",
        "Attapeu", "Xaignabouli", "Pakxan", "Houayxay", "Luang Namtha",
        "Saravan", "Phongsaly", "Ban Houayxay", "Muang Sing", "Khammouane"
    ],
    "Myanmar": [
        "Yangon", "Mandalay", "Naypyidaw", "Mawlamyine", "Bago",
        "Pathein", "Monywa", "Sittwe", "Meiktila", "Taunggyi",
        "Myeik", "Magway", "Lashio", "Pyay", "Hinthada",
        "Dawei", "Myingyan", "Pakokku", "Hpa-An", "Sagaing"
    ],
    "Lebanon": [
        "Beirut", "Tripoli", "Sidon", "Tyre", "Nabatieh",
        "Zahle", "Baalbek", "Jounieh", "Byblos", "Aley",
        "Batroun", "Halba", "Bint Jbeil", "Jezzine", "Rashaya",
        "Marjayoun", "Hasbeya", "Deir el Qamar", "Bcharré", "Zgharta"
    ],
    "Oman": [
        "Muscat", "Salalah", "Sohar", "Nizwa", "Sur",
        "Ibri", "Barka", "Rustaq", "Al Buraimi", "Saham",
        "Shinas", "Bahla", "Al Suwaiq", "Khasab", "Bidbid",
        "Liwa", "Masirah", "Adam", "Izki", "Ibra"
    ],
    "Bahrain": [
        "Manama", "Riffa", "Muharraq", "Hamad Town", "A'ali",
        "Isa Town", "Sitra", "Budaiya", "Jidhafs", "Al-Malikiyah",
        "Sanabis", "Tubli", "Dar Kulayb", "Barbar", "Galali",
        "Sanad", "Dumistan", "Juffair", "Adliya", "Saar"
    ],
    "Azerbaijan": [
        "Baku", "Ganja", "Sumqayit", "Mingachevir", "Lankaran",
        "Shirvan", "Nakhchivan", "Sheki", "Yevlakh", "Khankendi",
        "Gəncə", "Agdam", "Shamakhi", "Quba", "Qazakh",
        "Balakan", "Zaqatala", "Salyan", "Astara", "Goychay"
    ],
    "Georgia": [
        "Tbilisi", "Batumi", "Kutaisi", "Rustavi", "Gori",
        "Zugdidi", "Poti", "Khashuri", "Samtredia", "Senaki",
        "Zestaponi", "Marneuli", "Telavi", "Akhaltsikhe", "Kobuleti",
        "Ozurgeti", "Kaspi", "Chiatura", "Tsqaltubo", "Sagarejo"
    ],
    "Armenia": [
        "Yerevan", "Gyumri", "Vanadzor", "Vagharshapat", "Hrazdan",
        "Abovyan", "Kapan", "Armavir", "Gavar", "Artashat",
        "Goris", "Ashtarak", "Sevan", "Ijevan", "Charentsavan",
        "Ararat", "Vardenis", "Sisian", "Dilijan", "Metsamor"
    ],
    "Uzbekistan": [
        "Tashkent", "Namangan", "Samarkand", "Andijan", "Bukhara",
        "Nukus", "Qarshi", "Kokand", "Fergana", "Margilan",
        "Jizzakh", "Urgench", "Navoi", "Termez", "Chirchiq",
        "Angren", "Khiva", "Gulistan", "Bekabad", "Almaliq"
    ]
};
