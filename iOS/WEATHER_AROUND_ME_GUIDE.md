# Weather Around Me Guide

See weather in cities around you in all directions. This feature helps you understand regional weather patterns, track severe weather systems, and build an accurate mental map of conditions in your area.

## What You'll See

- **Regional Overview** - Weather in 8 directions (N, NE, E, SE, S, SW, W, NW)
- **Distance** - How far each city is from your selected city
- **Spatial Precision** - How far cities are from the center line (e.g., "5 miles west of center line")
- **Current Weather** - Temperature and conditions for each city
- **Weather Movement** - Whether weather systems are approaching, moving away, or moving parallel

## Exploring Along a Direction

Tap any direction to explore cities along that path. For example, tap "North" to see all cities north of your location.

- **Pick a Direction** - Choose N, NE, E, SE, S, SW, W, or NW from the picker
- **Navigate Cities** - Swipe up for cities farther away, swipe down for closer cities
- **Visual Buttons** - Use "Closer" and "Farther" buttons to move between cities
- **View All** - Tap "List All" to see all cities in that direction at once

## Understanding Spatial Information

VoiceOver can announce detailed spatial information to help you build an accurate mental map:

- **Distance from Center Line** - How far cities are offset east or west (e.g., "5 miles west of center line")
- **Bearing** - Compass direction in degrees (e.g., "145 degrees")
- **"On center line"** - City is directly along your chosen direction
- **Example:** "Janesville, 32 miles, 145 degrees, 25 miles east of center line" tells you distance, bearing, and offset

## Exploration Modes

Choose between two exploration modes in Settings → Weather Around Me:

- **Arc Mode** (default) - Fan-shaped search that expands outward like a cone. Cities within the arc width are included
- **Straight Line Corridor** - Fixed-width corridor along the center line. Cities within the corridor width are included regardless of distance

### Arc Widths (when using Arc mode)

- **Narrow (10°)** - Precise tracking, 17 miles wide at 100 miles
- **Standard (22.5°)** - Balanced coverage, 39 miles wide at 100 miles
- **Medium (45°)** - Broad search, 78 miles wide at 100 miles
- **Wide (90°)** - Maximum coverage, 141 miles wide at 100 miles

### Arc Width at Different Distances

The arc expands as you go farther from your starting city. Here's how wide each arc setting is at different distances:

| Distance | Narrow | Standard | Medium | Wide  |
|----------|--------|----------|--------|-------|
| 50 mi    | 9 mi   | 20 mi    | 38 mi  | 71 mi |
| 100 mi   | 17 mi  | 39 mi    | 77 mi  | 141 mi|
| 150 mi   | 26 mi  | 59 mi    | 115 mi | 212 mi|
| 200 mi   | 35 mi  | 78 mi    | 153 mi | 283 mi|
| 250 mi   | 44 mi  | 98 mi    | 191 mi | 354 mi|
| 300 mi   | 52 mi  | 117 mi   | 230 mi | 424 mi|

_For example, using Standard arc at 150 miles means cities must be within a 59-mile-wide fan shape at that distance to appear in your search._

### Corridor Widths (when using Straight Line Corridor mode)

- **10 miles** - ±5 miles from center line
- **20 miles** - ±10 miles from center line (default)
- **30 miles** - ±15 miles from center line
- **50 miles** - ±25 miles from center line

## Weather Movement Detection

When "Show Weather Movement" is enabled in settings, VoiceOver announces wind speed and whether weather systems are moving toward or away from your location. This uses wind direction data to analyze movement patterns.

- **"Winds X mph"** - Current wind speed when movement is minimal
- **"Approaching at X mph"** - Weather is moving toward your location
- **"Moving away at X mph"** - Weather is moving away from you
- **"Moving parallel at X mph"** - Weather is moving perpendicular to your direction

## Example VoiceOver Announcements

> _"Milwaukee, Wisconsin, 80 miles, 5 degrees, 3 miles east of center line, 72°F, Overcast, Alert: Tornado Warning, Approaching at 15 mph, Pressure steady, 2 of 15"_

With all settings enabled, you hear: city name, distance, bearing, offset from center line, temperature, conditions, weather alerts, wind movement, pressure trends, and position in list.

> _"Oregon, Wisconsin, 10 miles, 180 degrees, On center line, 65°F, Clear, Winds 3 mph, 1 of 8"_

## Configuring Weather Around Me

Access settings two ways: tap the gear icon in Weather Around Me, or go to Settings → Weather Around Me.

- **Default Distance** - How far to search (25-250 miles)
- **Exploration Mode** - Arc or Straight Line Corridor
- **Arc Width** or **Corridor Width** - Adjust based on your chosen mode
- **Show Distance from Center Line** - Toggle offset distance announcements (uses miles/kilometers)
- **Show Bearing** - Toggle compass bearing announcements (e.g., "145 degrees")
- **Show Weather Movement** - Toggle wind speed and movement direction
- **Show Pressure Trends** - Toggle pressure comparisons between consecutive cities
- **Show Weather Alerts** - Toggle severe weather alert announcements

## VoiceOver Quick Cycle

For experienced VoiceOver users, you can rapidly cycle through exploration modes without opening settings. Focus on the gear icon button and swipe up or down to cycle through all mode combinations.

- **Swipe Up** - Cycle forward: Corridor 10→20→30→50 miles, then Arc Narrow→Standard→Medium→Wide
- **Swipe Down** - Cycle backward through the same sequence
- **Instant Feedback** - VoiceOver announces the new mode and cities reload automatically
- **Example:** Quickly test different arc widths to see which captures the cities you want

## First Time Loading

Finding cities along a direction may take 10-20 seconds the first time, but results are cached for instant access next time. The app searches every 10-15 miles along your chosen direction to find nearby cities.

## Tips

- Use **Narrow Arc** or **10-mile Corridor** for precise tracking of severe weather along highways
- Use **Wide Arc** or **50-mile Corridor** to get a broader overview of regional conditions
- **Offset distance** helps you determine if a city is directly in the path of a weather system
- **Weather movement** helps you anticipate if storms are heading your way
- Use VoiceOver swipe gestures to quickly explore city by city
- Weather data is prefetched as you navigate for smooth scrolling
