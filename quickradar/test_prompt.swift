#!/usr/bin/env swift
// test_prompt.swift — Live radar prompt testing tool
//
// Downloads fresh NWS NEXRAD radar images on the Mac and runs them through
// the same Foundation Models as the iOS app. No phone needed.
//
// Run via:
//   ./quickradar/run_test_prompt.sh                         # all cities
//   ./quickradar/run_test_prompt.sh Madison                 # filter by city
//   ./quickradar/run_test_prompt.sh "New York"
//   ./quickradar/run_test_prompt.sh KMKX                    # by station ID
//
// Compile check only:
//   DEVELOPER_DIR=... swiftc -sdk ... -typecheck test_prompt.swift

import AppKit
import Foundation
import CoreGraphics
import ImageIO
import FoundationModels

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Prompt loading
// ─────────────────────────────────────────────────────────────────────────────

// Looks for prompt.txt in RadarData first, then falls back to the built-in.
// Edit RadarData/prompt.txt to iterate on the prompt without touching code.
let RADAR_DATA_DIR = URL(fileURLWithPath: NSHomeDirectory())
    .appendingPathComponent("Library/CloudStorage/OneDrive-Personal/RadarData")

func loadInterpretPrompt(cityName: String, locationHint: String) -> String {
    let promptFile = RADAR_DATA_DIR.appendingPathComponent("prompt.txt")
    if let template = try? String(contentsOf: promptFile, encoding: .utf8) {
        return template
            .replacingOccurrences(of: "{CITY}", with: cityName)
            .replacingOccurrences(of: "{LOCATION_HINT}", with: locationHint)
    }
    return interpretPrompt(cityName: cityName, locationHint: locationHint)
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - City / Station table
// ─────────────────────────────────────────────────────────────────────────────

struct RadarCity {
    let name: String
    let station: String
    let cityLat: Double      // city center latitude
    let cityLon: Double      // city center longitude
    let stationLat: Double   // radar station latitude (for annotation projection)
    let stationLon: Double   // radar station longitude
    let locationHint: String
}

let CITIES: [RadarCity] = [
    // Wisconsin
    RadarCity(name: "Madison WI",        station: "KMKX", cityLat: 43.0731, cityLon: -89.4012, stationLat: 42.9678, stationLon: -88.5506, locationHint: "in the LEFT/center-west portion of the image. The radar is centered on Milwaukee (center-right). Lake Michigan fills the far right. Madison is in Dane County — if precipitation is visible in Dane County, Madison is under it."),
    RadarCity(name: "Milwaukee WI",      station: "KMKX", cityLat: 43.0389, cityLon: -87.9065, stationLat: 42.9678, stationLon: -88.5506, locationHint: "near the center of the image — the radar (KMKX) is centered on Milwaukee"),
    RadarCity(name: "Green Bay WI",      station: "KGRB", cityLat: 44.5133, cityLon: -88.0133, stationLat: 44.4986, stationLon: -88.1114, locationHint: "near the center of the image — the radar (KGRB) is near Green Bay"),
    RadarCity(name: "Appleton WI",       station: "KGRB", cityLat: 44.2619, cityLon: -88.4154, stationLat: 44.4986, stationLon: -88.1114, locationHint: "toward the lower portion — the radar (KGRB) is north of Appleton"),
    RadarCity(name: "La Crosse WI",      station: "KARX", cityLat: 43.8014, cityLon: -91.2396, stationLat: 43.8228, stationLon: -91.1911, locationHint: "near the center of the image — the radar (KARX) is just northeast of La Crosse"),
    RadarCity(name: "Wausau WI",         station: "KGRB", cityLat: 44.9591, cityLon: -89.6301, stationLat: 44.4986, stationLon: -88.1114, locationHint: "toward the upper-left — the radar (KGRB) is southeast of Wausau"),
    // Pacific Northwest
    RadarCity(name: "Seattle WA",        station: "KATX", cityLat: 47.6062, cityLon: -122.3321, stationLat: 48.1944, stationLon: -122.4958, locationHint: "toward the lower-left — the radar (KATX) is north of Seattle"),
    RadarCity(name: "Redmond WA",        station: "KATX", cityLat: 47.6740, cityLon: -122.1215, stationLat: 48.1944, stationLon: -122.4958, locationHint: "toward the lower portion — the radar (KATX) is north and west of Redmond"),
    RadarCity(name: "Bellevue WA",       station: "KATX", cityLat: 47.6101, cityLon: -122.2015, stationLat: 48.1944, stationLon: -122.4958, locationHint: "toward the lower portion — the radar (KATX) is north and west of Bellevue"),
    RadarCity(name: "Tacoma WA",         station: "KATX", cityLat: 47.2529, cityLon: -122.4443, stationLat: 48.1944, stationLon: -122.4958, locationHint: "toward the lower portion — the radar (KATX) is north of Tacoma"),
    RadarCity(name: "Spokane WA",        station: "KOTX", cityLat: 47.6588, cityLon: -117.4260, stationLat: 47.6803, stationLon: -117.6267, locationHint: "near the center of the image — the radar (KOTX) is just west of Spokane"),
    RadarCity(name: "Portland OR",       station: "KRTX", cityLat: 45.5051, cityLon: -122.6750, stationLat: 45.7148, stationLon: -122.9647, locationHint: "toward the lower-right — the radar (KRTX) is northwest of Portland"),
    // Illinois / Midwest
    RadarCity(name: "Chicago IL",        station: "KLOT", cityLat: 41.8781, cityLon: -87.6298, stationLat: 41.6044, stationLon: -88.0844, locationHint: "toward the upper-right — the radar (KLOT, Romeoville) is southwest of Chicago. Lake Michigan is upper-right."),
    RadarCity(name: "Springfield IL",    station: "KILX", cityLat: 39.7817, cityLon: -89.6501, stationLat: 40.1506, stationLon: -89.3367, locationHint: "toward the lower-left — the radar (KILX) is northeast of Springfield"),
    RadarCity(name: "Indianapolis IN",   station: "KIND", cityLat: 39.7684, cityLon: -86.1581, stationLat: 39.7075, stationLon: -86.2803, locationHint: "near the center of the image — the radar (KIND) is just southwest of Indianapolis"),
    RadarCity(name: "Columbus OH",       station: "KILN", cityLat: 39.9612, cityLon: -82.9988, stationLat: 39.4203, stationLon: -83.8217, locationHint: "toward the upper-right — the radar (KILN) is southwest of Columbus"),
    RadarCity(name: "Cleveland OH",      station: "KCLE", cityLat: 41.4993, cityLon: -81.6944, stationLat: 41.4131, stationLon: -81.8598, locationHint: "near the center of the image — the radar (KCLE) is just west of Cleveland"),
    RadarCity(name: "Cincinnati OH",     station: "KILN", cityLat: 39.1031, cityLon: -84.5120, stationLat: 39.4203, stationLon: -83.8217, locationHint: "toward the lower-left — the radar (KILN) is northeast of Cincinnati"),
    RadarCity(name: "Detroit MI",        station: "KDTX", cityLat: 42.3314, cityLon: -83.0458, stationLat: 42.6999, stationLon: -83.4719, locationHint: "toward the lower-right — the radar (KDTX, White Lake) is northwest of Detroit"),
    RadarCity(name: "Kansas City MO",    station: "KEAX", cityLat: 39.0997, cityLon: -94.5786, stationLat: 38.8103, stationLon: -94.2644, locationHint: "toward the upper-left — the radar (KEAX) is southeast of Kansas City"),
    RadarCity(name: "St Louis MO",       station: "KLSX", cityLat: 38.6270, cityLon: -90.1994, stationLat: 38.6986, stationLon: -90.6828, locationHint: "toward the right — the radar (KLSX, Weldon Spring) is west of St Louis"),
    RadarCity(name: "Minneapolis MN",    station: "KMPX", cityLat: 44.9778, cityLon: -93.2650, stationLat: 44.8489, stationLon: -93.5653, locationHint: "toward the upper-right — the radar (KMPX, Chanhassen) is southwest of Minneapolis"),
    RadarCity(name: "Omaha NE",          station: "KOAX", cityLat: 41.2565, cityLon: -95.9345, stationLat: 41.3203, stationLon: -96.3667, locationHint: "toward the right — the radar (KOAX) is west of Omaha"),
    RadarCity(name: "Des Moines IA",     station: "KDMX", cityLat: 41.5868, cityLon: -93.6250, stationLat: 41.7311, stationLon: -93.7228, locationHint: "near the center of the image — the radar (KDMX) is just northwest of Des Moines"),
    // Texas
    RadarCity(name: "Dallas TX",         station: "KFWS", cityLat: 32.7767, cityLon: -96.7970, stationLat: 32.5730, stationLon: -97.3031, locationHint: "toward the upper-right — the radar (KFWS, Kennedale) is southwest of Dallas"),
    RadarCity(name: "Fort Worth TX",     station: "KFWS", cityLat: 32.7555, cityLon: -97.3308, stationLat: 32.5730, stationLon: -97.3031, locationHint: "toward the upper portion — the radar (KFWS, Kennedale) is south of Fort Worth"),
    RadarCity(name: "Houston TX",        station: "KHGX", cityLat: 29.7604, cityLon: -95.3698, stationLat: 29.4719, stationLon: -95.0789, locationHint: "toward the upper-left — the radar (KHGX, Dickinson) is south of Houston near Galveston Bay"),
    RadarCity(name: "San Antonio TX",    station: "KEWX", cityLat: 29.4241, cityLon: -98.4936, stationLat: 29.7038, stationLon: -98.0283, locationHint: "toward the lower-left — the radar (KEWX) is northeast of San Antonio"),
    RadarCity(name: "Austin TX",         station: "KEWX", cityLat: 30.2672, cityLon: -97.7431, stationLat: 29.7038, stationLon: -98.0283, locationHint: "toward the upper-right — the radar (KEWX) is south and west of Austin"),
    RadarCity(name: "Lubbock TX",        station: "KLBB", cityLat: 33.5779, cityLon: -101.8552, stationLat: 33.6542, stationLon: -101.8139, locationHint: "near the center of the image — the radar (KLBB) is just north of Lubbock"),
    RadarCity(name: "Amarillo TX",       station: "KAMA", cityLat: 35.2220, cityLon: -101.8313, stationLat: 35.2333, stationLon: -101.7092, locationHint: "near the center of the image — the radar (KAMA) is just east of Amarillo"),
    // Oklahoma
    RadarCity(name: "Oklahoma City OK",  station: "KTLX", cityLat: 35.4676, cityLon: -97.5164, stationLat: 35.3331, stationLon: -97.2778, locationHint: "toward the upper-left — the radar (KTLX, Twin Lakes) is southeast of Oklahoma City"),
    RadarCity(name: "Norman OK",         station: "KTLX", cityLat: 35.2226, cityLon: -97.4395, stationLat: 35.3331, stationLon: -97.2778, locationHint: "toward the lower-left — the radar (KTLX) is northeast of Norman"),
    RadarCity(name: "Tulsa OK",          station: "KINX", cityLat: 36.1540, cityLon: -95.9928, stationLat: 36.1753, stationLon: -95.5644, locationHint: "toward the left — the radar (KINX) is east of Tulsa"),
    RadarCity(name: "Wichita KS",        station: "KICT", cityLat: 37.6872, cityLon: -97.3301, stationLat: 37.6544, stationLon: -97.4425, locationHint: "near the center of the image — the radar (KICT) is just southwest of Wichita"),
    // Southeast
    RadarCity(name: "Atlanta GA",        station: "KFFC", cityLat: 33.7490, cityLon: -84.3880, stationLat: 33.3636, stationLon: -84.5658, locationHint: "toward the upper-center — the radar (KFFC, Peachtree City) is south of Atlanta"),
    RadarCity(name: "Charlotte NC",      station: "KGSP", cityLat: 35.2271, cityLon: -80.8431, stationLat: 34.8833, stationLon: -82.2208, locationHint: "toward the upper-right — the radar (KGSP, Greer) is west of Charlotte"),
    RadarCity(name: "Raleigh NC",        station: "KRAX", cityLat: 35.7796, cityLon: -78.6382, stationLat: 35.6656, stationLon: -78.4897, locationHint: "near the center of the image — the radar (KRAX) is just southeast of Raleigh"),
    RadarCity(name: "Nashville TN",      station: "KOHX", cityLat: 36.1627, cityLon: -86.7816, stationLat: 36.2472, stationLon: -86.5625, locationHint: "near the center — the radar (KOHX) is northeast of Nashville"),
    RadarCity(name: "Memphis TN",        station: "KNQA", cityLat: 35.1495, cityLon: -90.0490, stationLat: 35.3447, stationLon: -89.8733, locationHint: "toward the lower-left — the radar (KNQA) is north and east of Memphis"),
    RadarCity(name: "Birmingham AL",     station: "KBMX", cityLat: 33.5186, cityLon: -86.8104, stationLat: 33.1719, stationLon: -86.7700, locationHint: "toward the upper portion — the radar (KBMX) is south of Birmingham"),
    RadarCity(name: "New Orleans LA",    station: "KLIX", cityLat: 29.9511, cityLon: -90.0715, stationLat: 30.3367, stationLon: -89.8256, locationHint: "toward the lower-left — the radar (KLIX, Slidell) is north and east of New Orleans"),
    RadarCity(name: "Hattiesburg MS",    station: "KLIX", cityLat: 31.3271, cityLon: -89.2903, stationLat: 30.3367, stationLon: -89.8256, locationHint: "toward the upper-left — the radar (KLIX, Slidell) is southeast of Hattiesburg"),
    RadarCity(name: "Jacksonville FL",   station: "KJAX", cityLat: 30.3322, cityLon: -81.6557, stationLat: 30.4844, stationLon: -81.7019, locationHint: "near the center of the image — the radar (KJAX) is just north of Jacksonville"),
    RadarCity(name: "Tampa FL",          station: "KTBW", cityLat: 27.9506, cityLon: -82.4572, stationLat: 27.7055, stationLon: -82.4017, locationHint: "toward the upper portion — the radar (KTBW, Ruskin) is south of Tampa"),
    RadarCity(name: "Orlando FL",        station: "KMLB", cityLat: 28.5383, cityLon: -81.3792, stationLat: 28.1131, stationLon: -80.6542, locationHint: "toward the upper-left — the radar (KMLB, Melbourne) is southeast of Orlando"),
    RadarCity(name: "Miami FL",          station: "KAMX", cityLat: 25.7617, cityLon: -80.1918, stationLat: 25.6111, stationLon: -80.4128, locationHint: "toward the upper-right — the radar (KAMX, Homestead) is southwest of Miami"),
    // Mid-Atlantic / Northeast
    RadarCity(name: "Washington DC",     station: "KLWX", cityLat: 38.9072, cityLon: -77.0369, stationLat: 38.9753, stationLon: -77.4778, locationHint: "toward the right — the radar (KLWX, Sterling VA) is west of DC"),
    RadarCity(name: "Baltimore MD",      station: "KLWX", cityLat: 39.2904, cityLon: -76.6122, stationLat: 38.9753, stationLon: -77.4778, locationHint: "toward the upper-right — the radar (KLWX, Sterling VA) is southwest of Baltimore"),
    RadarCity(name: "Philadelphia PA",   station: "KDIX", cityLat: 39.9526, cityLon: -75.1652, stationLat: 39.9469, stationLon: -74.4108, locationHint: "toward the left — the radar (KDIX) is east of Philadelphia"),
    RadarCity(name: "New York NY",       station: "KOKX", cityLat: 40.7128, cityLon: -74.0060, stationLat: 40.8656, stationLon: -72.8644, locationHint: "toward the upper-left — the radar (KOKX) is on Long Island to the northeast"),
    RadarCity(name: "Newark NJ",         station: "KDIX", cityLat: 40.7357, cityLon: -74.1724, stationLat: 39.9469, stationLon: -74.4108, locationHint: "toward the upper-left — the radar (KDIX) is south of Newark"),
    RadarCity(name: "Boston MA",         station: "KBOX", cityLat: 42.3601, cityLon: -71.0589, stationLat: 41.9558, stationLon: -71.1369, locationHint: "toward the upper-center — the radar (KBOX, Taunton) is south of Boston"),
    RadarCity(name: "Pittsburgh PA",     station: "KPBZ", cityLat: 40.4406, cityLon: -79.9959, stationLat: 40.5317, stationLon: -80.2178, locationHint: "near the center of the image — the radar (KPBZ) is northwest of Pittsburgh"),
    RadarCity(name: "Buffalo NY",        station: "KBUF", cityLat: 42.8864, cityLon: -78.8784, stationLat: 42.9486, stationLon: -78.7369, locationHint: "near the center of the image — the radar (KBUF) is just northeast of Buffalo"),
    RadarCity(name: "Richmond VA",       station: "KAKQ", cityLat: 37.5407, cityLon: -77.4360, stationLat: 36.9839, stationLon: -77.0075, locationHint: "toward the upper-left — the radar (KAKQ) is southeast of Richmond"),
    // Mountain / Southwest
    RadarCity(name: "Denver CO",         station: "KFTG", cityLat: 39.7392, cityLon: -104.9903, stationLat: 39.7867, stationLon: -104.5458, locationHint: "toward the left — the radar (KFTG, Watkins) is east of Denver"),
    RadarCity(name: "Salt Lake City UT", station: "KMTX", cityLat: 40.7608, cityLon: -111.8910, stationLat: 41.2628, stationLon: -112.4481, locationHint: "toward the lower-right — the radar (KMTX) is north and west of Salt Lake City"),
    RadarCity(name: "Phoenix AZ",        station: "KIWA", cityLat: 33.4484, cityLon: -112.0740, stationLat: 33.2892, stationLon: -111.6697, locationHint: "toward the upper-left — the radar (KIWA, Chandler) is southeast of Phoenix"),
    RadarCity(name: "Tucson AZ",         station: "KEMX", cityLat: 32.2226, cityLon: -110.9747, stationLat: 31.8936, stationLon: -110.6306, locationHint: "toward the upper-left — the radar (KEMX) is southeast of Tucson"),
    RadarCity(name: "Albuquerque NM",    station: "KABX", cityLat: 35.0844, cityLon: -106.6504, stationLat: 35.1497, stationLon: -106.8228, locationHint: "toward the right — the radar (KABX) is west of Albuquerque"),
    RadarCity(name: "Las Vegas NV",      station: "KESX", cityLat: 36.1699, cityLon: -115.1398, stationLat: 35.7011, stationLon: -114.8919, locationHint: "toward the upper-left — the radar (KESX, Henderson) is southeast of Las Vegas"),
    // California
    RadarCity(name: "Los Angeles CA",    station: "KVTX", cityLat: 34.0522, cityLon: -118.2437, stationLat: 34.4117, stationLon: -119.1792, locationHint: "toward the right — the radar (KVTX) is northwest of Los Angeles"),
    RadarCity(name: "San Diego CA",      station: "KNKX", cityLat: 32.7157, cityLon: -117.1611, stationLat: 32.9189, stationLon: -117.0417, locationHint: "toward the lower portion — the radar (KNKX) is north of San Diego"),
    RadarCity(name: "San Francisco CA",  station: "KMUX", cityLat: 37.7749, cityLon: -122.4194, stationLat: 37.1550, stationLon: -121.8983, locationHint: "toward the upper-left — the radar (KMUX, Loma Prieta) is southeast of San Francisco"),
    RadarCity(name: "Sacramento CA",     station: "KDAX", cityLat: 38.5816, cityLon: -121.4944, stationLat: 38.5011, stationLon: -121.6778, locationHint: "near the center — the radar (KDAX) is southwest of Sacramento"),
    // Alaska
    RadarCity(name: "Anchorage AK",      station: "PAHG", cityLat: 61.2176, cityLon: -149.8997, stationLat: 59.4619, stationLon: -151.3511, locationHint: "in the upper-right — the radar (PAHG, Homer) is far to the south on the Kenai Peninsula, about 200km south of Anchorage. Anchorage and the Matanuska-Susitna Valley appear in the upper portion; Cook Inlet runs diagonally through the center."),
    RadarCity(name: "Fairbanks AK",      station: "PAPD", cityLat: 64.8378, cityLon: -147.7164, stationLat: 65.0351, stationLon: -147.5014, locationHint: "near the center — the radar (PAPD) is just north of Fairbanks"),
    RadarCity(name: "Juneau AK",         station: "PACG", cityLat: 58.3005, cityLon: -134.4197, stationLat: 56.8528, stationLon: -135.5292, locationHint: "in the upper-right — the radar (PACG, Sitka) is to the south. Southeast Alaska's geography is a narrow coastal strip running northwest; Juneau appears in the upper-right portion of the image."),
    // Hawaii
    RadarCity(name: "Honolulu HI",       station: "PHMO", cityLat: 21.3069, cityLon: -157.8583, stationLat: 21.1328, stationLon: -157.1808, locationHint: "toward the left/west — the radar (PHMO, Molokai) is to the east. Oahu (where Honolulu is) appears as an island shape to the west/left of center. Ocean surrounds all land; look for island outlines."),
    RadarCity(name: "Hilo HI",           station: "PHKM", cityLat: 19.7297, cityLon: -155.0900, stationLat: 20.1255, stationLon: -155.7783, locationHint: "in the lower-right — the radar (PHKM, Kohala) is on the northwest tip of the Big Island. Hilo is on the east coast, lower-right in the image."),
]

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Prompts (keep in sync with RadarFoundationModelsService.swift)
// ─────────────────────────────────────────────────────────────────────────────

func cityLocator(cityName: String, locationHint: String, plural: Bool = false) -> String {
    let imageRef = plural ? "Both images are" : "This image is"
    return """
    LOCATING \(cityName): \(imageRef) centered on a radar station, NOT on \(cityName). \(cityName) is \(locationHint)

    Describe where precipitation actually IS using the named cities, counties, and geographic features visible on the map. Then state clearly whether \(cityName) itself is under precipitation or is clear. Do NOT assume precipitation elsewhere on the map is near \(cityName) — report where it actually is by name.
    """
}

func interpretPrompt(cityName: String, locationHint: String) -> String {
    """
    You are interpreting a weather radar image for \(cityName).

    \(cityLocator(cityName: cityName, locationHint: locationHint))

    IMPORTANT — things in this image that are NOT precipitation or warnings:
    • TOP OF IMAGE: A legend strip showing colored boxes labeled TORNADO, SEVERE THUNDERSTORM, FLASH FLOOD, SPECIAL MARINE, SNOW SQUALL. These are reference labels — NOT active warnings. Ignore them.
    • BOTTOM OF IMAGE: A color scale bar (dBZ range). Reference only.
    • RED/BROWN LINES throughout the map: County and state border lines. NOT warnings.
    • BLUE/TEAL FILLED REGION (Lake Michigan, lakes): Solid, fixed shape on the eastern edge of the map — NOT precipitation. Do NOT confuse this with blue precipitation echoes.
    • BLUE PATCHES scattered across the map: These ARE real precipitation (light rain, 5–35 dBZ). Blue is the most common precipitation color and must not be ignored or mistaken for water.
    • White or blank map area = no precipitation.

    An ACTIVE WARNING POLYGON looks like: a large thick colored outline drawn directly over the map geography, enclosing a county-sized area. Clearly separate from the thin county border grid.

    Answer these three questions in plain language, 1–2 sentences each:
    1. Where is precipitation (blue=light, green=moderate, yellow=heavy, red=very heavy) on this map right now? Name every city, county, or region that has any color over it.
    2. Based only on what you described in question 1: if someone is standing in \(cityName), are they likely in the rain right now, or is the sky above them clear? Use the location hint above to decide.
    3. Are there any thick colored polygon outlines drawn directly over the map (NOT the top legend boxes)? Those are active warnings.
    No technical jargon.
    """
}

func movementPrompt(cityName: String, locationHint: String) -> String {
    """
    You are looking at two weather radar images for \(cityName), taken about 20 minutes apart. The first image is earlier, the second is later.

    \(cityLocator(cityName: cityName, locationHint: locationHint, plural: true))

    IMPORTANT — NOT precipitation or warnings:
    • TOP: Legend strip (TORNADO, SEVERE THUNDERSTORM, etc.) — reference labels, not active.
    • BOTTOM: Color scale bar — reference only.
    • RED/BROWN LINES: County and state borders — always present, NOT warnings.
    • BLUE/TEAL FILLED REGION (Lake Michigan, lakes): Solid, fixed shape on the eastern edge — NOT precipitation.
    • BLUE PATCHES scattered across the map: These ARE real precipitation (light rain). Blue is the most common precipitation color — do not ignore it or mistake it for water.
    • White/blank = no precipitation.

    In 2–3 sentences: Name where the precipitation (blue, green, yellow, red, purple) is and how it moved between frames — which cities or regions gained or lost coverage. Blue patches are light rain and count as precipitation. Is it moving toward \(cityName) or away? What should someone in \(cityName) expect in the coming hour? If both frames show no precipitation, say so clearly.
    """
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Download
// ─────────────────────────────────────────────────────────────────────────────

func downloadRadarImage(station: String, frameIndex: Int = 0) async -> (data: Data, image: CGImage)? {
    let sid = station.uppercased()
    let urlStr = "https://radar.weather.gov/ridge/standard/\(sid)_\(frameIndex).gif"
    guard let url = URL(string: urlStr) else { return nil }

    do {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        return (data, image)
    } catch {
        return nil
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Image annotation
// ─────────────────────────────────────────────────────────────────────────────

// Projects city center to pixel coordinates in the NWS RIDGE image.
// NEXRAD standard view covers ~248km from the station center in each direction.
// Returns nil if station coordinates are zero (unknown station position).
func projectCityToPixel(city: RadarCity, imageWidth: Int, imageHeight: Int) -> CGPoint? {
    guard city.stationLat != 0 || city.stationLon != 0 else { return nil }
    let rangeKm = 248.0
    let latRad  = city.stationLat * .pi / 180
    let kmEast  = (city.cityLon - city.stationLon) * cos(latRad) * 111.0  // positive = city is east (right)
    let kmNorth = (city.cityLat - city.stationLat) * 111.0                 // positive = city is north (up)
    let halfW   = Double(imageWidth)  / 2.0
    let halfH   = Double(imageHeight) / 2.0
    let px = halfW + kmEast  * (halfW / rangeKm)
    let py = halfH - kmNorth * (halfH / rangeKm)   // image y increases downward
    return CGPoint(x: px, y: py)
}

// Draws a red dot with a white halo at the given image-coordinate point.
// CoreGraphics origin is bottom-left; image coordinates are top-left — we flip here.
func annotateImage(_ source: CGImage, at point: CGPoint) -> CGImage? {
    let w = source.width
    let h = source.height
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
        isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0),
    let nsCtx = NSGraphicsContext(bitmapImageRep: rep)
    else { return nil }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = nsCtx

    // NSImage handles the CGImage→screen coordinate flip correctly
    NSImage(cgImage: source, size: NSSize(width: w, height: h))
        .draw(in: NSRect(x: 0, y: 0, width: w, height: h))

    // NSImage uses bottom-left origin, so convert point.y from top-left
    let dotX = point.x
    let dotY = CGFloat(h) - point.y
    NSColor.white.setFill()
    NSBezierPath(ovalIn: NSRect(x: dotX - 13, y: dotY - 13, width: 26, height: 26)).fill()
    NSColor(red: 0.9, green: 0.05, blue: 0.05, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: dotX - 9, y: dotY - 9, width: 18, height: 18)).fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep.cgImage
}

func savePNG(_ image: CGImage, to url: URL) {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else { return }
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Test one city
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Logging
// ─────────────────────────────────────────────────────────────────────────────

func logDir() -> URL {
    RADAR_DATA_DIR.appendingPathComponent("test_logs", isDirectory: true)
}

func writeLog(city: RadarCity,
              singleFrame: String, annotatedSingle: String?,
              twoFrame: String?,   annotatedTwo: String?,
              currentGIF: Data,    priorGIF: Data?,
              annotatedCurrentPNG: CGImage?, annotatedPriorPNG: CGImage?) {
    let dir = logDir()

    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd_HHmmss"
    formatter.timeZone = TimeZone(identifier: "UTC")
    let stamp = formatter.string(from: Date())
    let slug = city.name
        .components(separatedBy: CharacterSet.alphanumerics.inverted)
        .filter { !$0.isEmpty }.joined(separator: "_")

    let folderURL = dir.appendingPathComponent("\(stamp)_\(slug)", isDirectory: true)
    try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

    // Save radar images
    try? currentGIF.write(to: folderURL.appendingPathComponent("current.gif"))
    if let p = priorGIF { try? p.write(to: folderURL.appendingPathComponent("prior.gif")) }
    if let img = annotatedCurrentPNG { savePNG(img, to: folderURL.appendingPathComponent("annotated_current.png")) }
    if let img = annotatedPriorPNG   { savePNG(img, to: folderURL.appendingPathComponent("annotated_prior.png")) }

    // Save text results
    let isoFormatter = ISO8601DateFormatter()
    var lines: [String] = [
        "City:    \(city.name)",
        "Station: \(city.station)",
        "Time:    \(isoFormatter.string(from: Date()))",
        "",
        "--- Single Frame (no annotation) ---",
        singleFrame,
    ]
    if let as_ = annotatedSingle {
        lines += ["", "--- Single Frame (annotated) ---", as_]
    }
    if let tf = twoFrame {
        lines += ["", "--- Two Frame movement (no annotation) ---", tf]
    }
    if let at = annotatedTwo {
        lines += ["", "--- Two Frame movement (annotated) ---", at]
    }
    let content = lines.joined(separator: "\n") + "\n"
    try? content.write(to: folderURL.appendingPathComponent("results.txt"), atomically: true, encoding: .utf8)
    print("Logged to test_logs/\(stamp)_\(slug)/")
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Test one city
// ─────────────────────────────────────────────────────────────────────────────

@available(macOS 27.0, *)
func testCity(_ city: RadarCity) async {
    print("\n\(city.name)  (station: \(city.station))")
    print(String(repeating: "-", count: city.name.count + city.station.count + 13))

    async let frame0Task = downloadRadarImage(station: city.station, frameIndex: 0)
    async let frame1Task = downloadRadarImage(station: city.station, frameIndex: 1)
    let (frame0, frame1) = await (frame0Task, frame1Task)

    guard let current = frame0 else {
        print("Could not download radar image for \(city.station)")
        return
    }

    // Build annotated versions if we have coordinates
    let dot = projectCityToPixel(city: city, imageWidth: current.image.width, imageHeight: current.image.height)
    let annotatedCurrent: CGImage? = dot.flatMap { annotateImage(current.image, at: $0) }
    let annotatedPrior: CGImage?   = dot.flatMap { pt in frame1.flatMap { annotateImage($0.image, at: pt) } }

    let annotationNote = "A small red dot on the map marks \(city.name)'s exact location. Use it as the ground truth for where \(city.name) is — the dot overrides any city label text on the map."

    var singleFrameResult    = ""
    var annotatedSingleResult: String? = nil
    var twoFrameResult:       String? = nil
    var annotatedTwoResult:   String? = nil

    print("\nCurrent radar (no annotation):")
    do {
        let session = LanguageModelSession()
        let response = try await session.respond {
            loadInterpretPrompt(cityName: city.name, locationHint: city.locationHint)
            Attachment(current.image)
        }
        singleFrameResult = response.content
        print(singleFrameResult)
    } catch {
        singleFrameResult = "Error: \(error)"
        print(singleFrameResult)
    }

    if let annotated = annotatedCurrent {
        print("\nCurrent radar (red dot marks \(city.name)):")
        do {
            let prompt = loadInterpretPrompt(cityName: city.name, locationHint: city.locationHint) + "\n\n" + annotationNote
            let session = LanguageModelSession()
            let response = try await session.respond {
                prompt
                Attachment(annotated)
            }
            annotatedSingleResult = response.content
            print(annotatedSingleResult!)
        } catch {
            annotatedSingleResult = "Error: \(error)"
            print(annotatedSingleResult!)
        }
    }

    if let prior = frame1 {
        print("\nMovement (no annotation):")
        do {
            let session = LanguageModelSession()
            let response = try await session.respond {
                movementPrompt(cityName: city.name, locationHint: city.locationHint)
                Attachment(prior.image)
                Attachment(current.image)
            }
            twoFrameResult = response.content
            print(twoFrameResult!)
        } catch {
            twoFrameResult = "Error: \(error)"
            print(twoFrameResult!)
        }

        if let annotatedC = annotatedCurrent, let annotatedP = annotatedPrior {
            print("\nMovement (red dot marks \(city.name)):")
            do {
                let prompt = movementPrompt(cityName: city.name, locationHint: city.locationHint) + "\n\n" + annotationNote
                let session = LanguageModelSession()
                let response = try await session.respond {
                    prompt
                    Attachment(annotatedP)
                    Attachment(annotatedC)
                }
                annotatedTwoResult = response.content
                print(annotatedTwoResult!)
            } catch {
                annotatedTwoResult = "Error: \(error)"
                print(annotatedTwoResult!)
            }
        }
    }

    writeLog(city: city,
             singleFrame: singleFrameResult, annotatedSingle: annotatedSingleResult,
             twoFrame: twoFrameResult,        annotatedTwo: annotatedTwoResult,
             currentGIF: current.data,        priorGIF: frame1?.data,
             annotatedCurrentPNG: annotatedCurrent, annotatedPriorPNG: annotatedPrior)
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Run
// ─────────────────────────────────────────────────────────────────────────────

@available(macOS 27.0, *)
func run(filter: String?) async {
    let model = SystemLanguageModel.default
    guard case .available = model.availability else {
        print("Foundation Models not available: \(model.availability)")
        return
    }

    let targets: [RadarCity]
    if let f = filter {
        // Normalize input: strip zip codes and commas, collapse whitespace
        var normalized = f
        if let regex = try? NSRegularExpression(pattern: #"\b\d{5}(-\d{4})?\b"#) {
            let range = NSRange(normalized.startIndex..., in: normalized)
            normalized = regex.stringByReplacingMatches(in: normalized, range: range, withTemplate: "")
        }
        normalized = normalized.replacingOccurrences(of: ",", with: " ")
        normalized = normalized.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)

        let normLower = normalized.lowercased()
        let words = normLower.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

        let matched = CITIES.filter { city in
            let nameLower = city.name.lowercased()
            // Station ID exact match
            if city.station.lowercased() == normLower { return true }
            // Name contains input or input contains name
            if nameLower.contains(normLower) || normLower.contains(nameLower) { return true }
            // Every word in input appears in city name (handles "Milwaukee" → "Milwaukee WI")
            return !words.isEmpty && words.allSatisfy { nameLower.contains($0) }
        }

        if matched.isEmpty {
            let suggestions = CITIES.map { $0.name }.sorted().joined(separator: ", ")
            print("No match for '\(f)'. Supported cities:\n\(suggestions)\nOr enter a station ID directly (e.g. KMKX).")
            return
        }
        targets = matched
    } else {
        targets = CITIES
    }

    for city in targets {
        await testCity(city)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Entry point
// ─────────────────────────────────────────────────────────────────────────────


let filter: String? = CommandLine.arguments.count > 1 ? CommandLine.arguments.dropFirst().joined(separator: " ") : nil

Task {
    if #available(macOS 27.0, *) {
        await run(filter: filter)
    } else {
        print("Requires macOS 27+")
    }
    exit(0)
}
RunLoop.main.run()
