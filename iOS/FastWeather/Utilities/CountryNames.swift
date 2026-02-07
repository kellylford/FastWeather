//
//  CountryNames.swift
//  FastWeather
//
//  Country code mapping for normalizing country names to US English
//

import Foundation

/// Utility for normalizing country names from various sources to US English
struct CountryNames {
    
    // MARK: - ISO 3166-1 alpha-2 to English Mapping
    
    /// Maps ISO country codes to US English country names
    static let isoToEnglish: [String: String] = [
        // North America
        "US": "United States",
        "CA": "Canada",
        "MX": "Mexico",
        "BS": "Bahamas",
        "BB": "Barbados",
        "CU": "Cuba",
        "DO": "Dominican Republic",
        "HT": "Haiti",
        "JM": "Jamaica",
        "TT": "Trinidad and Tobago",
        "PR": "Puerto Rico",
        
        // South America
        "AR": "Argentina",
        "BO": "Bolivia",
        "BR": "Brazil",
        "CL": "Chile",
        "CO": "Colombia",
        "EC": "Ecuador",
        "GY": "Guyana",
        "PY": "Paraguay",
        "PE": "Peru",
        "SR": "Suriname",
        "UY": "Uruguay",
        "VE": "Venezuela",
        
        // Europe - Western
        "GB": "United Kingdom",
        "IE": "Ireland",
        "FR": "France",
        "ES": "Spain",
        "PT": "Portugal",
        "IT": "Italy",
        "DE": "Germany",
        "AT": "Austria",
        "CH": "Switzerland",
        "NL": "Netherlands",
        "BE": "Belgium",
        "LU": "Luxembourg",
        
        // Europe - Northern
        "DK": "Denmark",
        "NO": "Norway",
        "SE": "Sweden",
        "FI": "Finland",
        "IS": "Iceland",
        
        // Europe - Eastern
        "PL": "Poland",
        "CZ": "Czech Republic",
        "SK": "Slovakia",
        "HU": "Hungary",
        "RO": "Romania",
        "BG": "Bulgaria",
        "UA": "Ukraine",
        "BY": "Belarus",
        "MD": "Moldova",
        "RU": "Russia",
        
        // Europe - Southern
        "GR": "Greece",
        "AL": "Albania",
        "HR": "Croatia",
        "SI": "Slovenia",
        "BA": "Bosnia and Herzegovina",
        "RS": "Serbia",
        "ME": "Montenegro",
        "MK": "North Macedonia",
        "XK": "Kosovo",
        
        // Europe - Baltic
        "EE": "Estonia",
        "LV": "Latvia",
        "LT": "Lithuania",
        
        // Asia - East
        "CN": "China",
        "JP": "Japan",
        "KR": "South Korea",
        "KP": "North Korea",
        "MN": "Mongolia",
        "TW": "Taiwan",
        "HK": "Hong Kong",
        "MO": "Macau",
        
        // Asia - Southeast
        "TH": "Thailand",
        "VN": "Vietnam",
        "MM": "Myanmar",
        "LA": "Laos",
        "KH": "Cambodia",
        "MY": "Malaysia",
        "SG": "Singapore",
        "ID": "Indonesia",
        "PH": "Philippines",
        "BN": "Brunei",
        "TL": "Timor-Leste",
        
        // Asia - South
        "IN": "India",
        "PK": "Pakistan",
        "BD": "Bangladesh",
        "LK": "Sri Lanka",
        "NP": "Nepal",
        "BT": "Bhutan",
        "MV": "Maldives",
        "AF": "Afghanistan",
        
        // Asia - Central
        "KZ": "Kazakhstan",
        "UZ": "Uzbekistan",
        "TM": "Turkmenistan",
        "TJ": "Tajikistan",
        "KG": "Kyrgyzstan",
        
        // Middle East
        "TR": "Turkey",
        "IR": "Iran",
        "IQ": "Iraq",
        "SY": "Syria",
        "JO": "Jordan",
        "LB": "Lebanon",
        "IL": "Israel",
        "PS": "Palestine",
        "SA": "Saudi Arabia",
        "AE": "United Arab Emirates",
        "QA": "Qatar",
        "KW": "Kuwait",
        "BH": "Bahrain",
        "OM": "Oman",
        "YE": "Yemen",
        
        // Africa - North
        "EG": "Egypt",
        "LY": "Libya",
        "TN": "Tunisia",
        "DZ": "Algeria",
        "MA": "Morocco",
        "SD": "Sudan",
        "SS": "South Sudan",
        
        // Africa - West
        "NG": "Nigeria",
        "GH": "Ghana",
        "SN": "Senegal",
        "CI": "Ivory Coast",
        "ML": "Mali",
        "BF": "Burkina Faso",
        "NE": "Niger",
        "GM": "Gambia",
        "GN": "Guinea",
        "SL": "Sierra Leone",
        "LR": "Liberia",
        "TG": "Togo",
        "BJ": "Benin",
        
        // Africa - East
        "ET": "Ethiopia",
        "KE": "Kenya",
        "TZ": "Tanzania",
        "UG": "Uganda",
        "RW": "Rwanda",
        "BI": "Burundi",
        "SO": "Somalia",
        "DJ": "Djibouti",
        "ER": "Eritrea",
        
        // Africa - Southern
        "ZA": "South Africa",
        "ZW": "Zimbabwe",
        "ZM": "Zambia",
        "MW": "Malawi",
        "MZ": "Mozambique",
        "BW": "Botswana",
        "NA": "Namibia",
        "LS": "Lesotho",
        "SZ": "Eswatini",
        
        // Africa - Central
        "CD": "Democratic Republic of the Congo",
        "CG": "Republic of the Congo",
        "CM": "Cameroon",
        "CF": "Central African Republic",
        "TD": "Chad",
        "AO": "Angola",
        "GA": "Gabon",
        "GQ": "Equatorial Guinea",
        
        // Oceania
        "AU": "Australia",
        "NZ": "New Zealand",
        "PG": "Papua New Guinea",
        "FJ": "Fiji",
        "SB": "Solomon Islands",
        "VU": "Vanuatu",
        "NC": "New Caledonia",
        "PF": "French Polynesia",
        "WS": "Samoa",
        "TO": "Tonga",
        "KI": "Kiribati",
        "FM": "Micronesia",
        "MH": "Marshall Islands",
        "PW": "Palau",
        
        // Caribbean (additional)
        "BZ": "Belize",
        "CR": "Costa Rica",
        "SV": "El Salvador",
        "GT": "Guatemala",
        "HN": "Honduras",
        "NI": "Nicaragua",
        "PA": "Panama",
    ]
    
    // MARK: - Native/Alternate Names to English Mapping
    
    /// Maps native and alternate country names to US English (for migration)
    static let nativeToEnglish: [String: String] = [
        // Germany variations
        "Deutschland": "Germany",
        
        // Austria variations
        "Österreich": "Austria",
        
        // Vietnam variations
        "Việt Nam": "Vietnam",
        "Viet Nam": "Vietnam",
        
        // Brazil variations
        "Brasil": "Brazil",
        
        // Belgium variations (multi-language country)
        "België / Belgique / Belgien": "Belgium",
        "België": "Belgium",
        "Belgique": "Belgium",
        "Belgien": "Belgium",
        
        // Denmark variations
        "Danmark": "Denmark",
        
        // Finland variations
        "Suomi": "Finland",
        
        // Greece variations
        "Ελλάδα": "Greece",
        "Ellada": "Greece",
        
        // Netherlands variations
        "Nederland": "Netherlands",
        
        // Norway variations
        "Norge": "Norway",
        
        // Sweden variations
        "Sverige": "Sweden",
        
        // Switzerland variations
        "Schweiz / Suisse / Svizzera": "Switzerland",
        "Schweiz": "Switzerland",
        "Suisse": "Switzerland",
        "Svizzera": "Switzerland",
        
        // Czech Republic variations
        "Česká republika": "Czech Republic",
        "Česko": "Czech Republic",
        
        // Poland variations
        "Polska": "Poland",
        
        // Hungary variations
        "Magyarország": "Hungary",
        
        // Croatia variations
        "Hrvatska": "Croatia",
        
        // Slovenia variations
        "Slovenija": "Slovenia",
        
        // Romania variations
        "România": "Romania",
        
        // Turkey variations
        "Türkiye": "Turkey",
        
        // Japan variations
        "日本": "Japan",
        "Nippon": "Japan",
        
        // China variations
        "中国": "China",
        "中華人民共和國": "China",
        "中华人民共和国": "China",
        "Zhongguo": "China",
        
        // South Korea variations
        "대한민국": "South Korea",
        "한국": "South Korea",
        
        // Thailand variations
        "ประเทศไทย": "Thailand",
        "Prathet Thai": "Thailand",
        
        // Egypt variations
        "مصر": "Egypt",
        "Misr": "Egypt",
        
        // Saudi Arabia variations
        "السعودية": "Saudi Arabia",
        "المملكة العربية السعودية": "Saudi Arabia",
        
        // United States variations
        "USA": "United States",
        "U.S.A.": "United States",
        "U.S.": "United States",
        "US": "United States",
        "United States of America": "United States",
        "America": "United States",
        
        // United Kingdom variations
        "UK": "United Kingdom",
        "U.K.": "United Kingdom",
        "Great Britain": "United Kingdom",
        "Britain": "United Kingdom",
        "England": "United Kingdom",
        
        // Russia variations
        "Россия": "Russia",
        "Rossiya": "Russia",
        "Russian Federation": "Russia",
        
        // South Africa variations
        "Suid-Afrika": "South Africa",
        
        // Common misspellings / variations
        "Phillipines": "Philippines",
        "Philipines": "Philippines",
    ]
    
    // MARK: - Normalization Functions
    
    /// Normalize a country name to US English
    /// - Parameters:
    ///   - countryName: Native or English country name
    ///   - isoCode: ISO 3166-1 alpha-2 country code (optional, preferred)
    /// - Returns: Normalized English country name, or original if unmapped
    static func normalize(_ countryName: String?, isoCode: String? = nil) -> String? {
        // Handle nil input
        guard let name = countryName, !name.isEmpty else {
            return countryName
        }
        
        // Try ISO code first (most reliable)
        if let code = isoCode?.uppercased(), !code.isEmpty {
            if let englishName = isoToEnglish[code] {
                return englishName
            }
        }
        
        // Fallback to native name lookup
        if let englishName = nativeToEnglish[name] {
            return englishName
        }
        
        // Return original if no mapping found (preserves data)
        return name
    }
    
    /// Check if a country name needs normalization
    /// - Parameter countryName: Country name to check
    /// - Returns: True if the name is in native language and should be normalized
    static func needsNormalization(_ countryName: String?) -> Bool {
        guard let name = countryName else { return false }
        return nativeToEnglish.keys.contains(name)
    }
}
