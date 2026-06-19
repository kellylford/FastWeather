# Sunny Days Ahead

## How AI Technical Prowess and Kelly Ford's Innovative Thinking Brought Weather Image Accessibility to WeatherFast

---

### A field guide to weather imagery for the innovator

*Prepared as a research and education document for the WeatherFast project.
This document answers two questions: (1) what kinds of weather images beyond
radar could be run through the same AI-description experiment, and (2) what are
the different kinds of weather images you can get and how do they differ?*

---

## Part One — The World of Weather Imagery: What Else Is Out There?

You already know radar. It is the image everyone talks about when severe
weather approaches — the green-and-yellow-and-red splatter that tells you
whether a storm is coming your way. But radar is only one member of a large
family of weather images that forecasters, meteorologists, and weather apps
use to understand the atmosphere. Each of these image types answers a
different question, and each is a candidate for the same experiment you are
running with QuickRadar: send the image to a vision-language model, ask for
a detailed screen-reader-friendly description, and compare that description
against the numeric data you can fetch from an API.

Below is a tour of the weather image types that routinely appear in weather
apps, on broadcast television, and in forecasting workflows. For each one I
note what it shows, where you can get it for free, and why it matters for an
accessibility-first app like WeatherFast.

### 1. Radar Reflectivity (the one you know)

This is the classic precipitation image. A weather radar dish sends out a
pulse of microwave energy; some of it bounces off raindrops, snowflakes, or
hail and comes back. The strength of the return (reflectivity, measured in
dBZ) is mapped to color: light green for light rain, yellow for moderate,
red for heavy, purple for extreme hail. The image you are downloading in
QuickRadar — the NWS RIDGE base-reflectivity GIF — is exactly this.

**What it answers:** Is there precipitation, where, and how intense?

**Free sources:** NWS RIDGE (what QuickRadar uses), Iowa Environmental
Mesonet NEXRAD composite tiles (what WeatherFast's `RadarTileService.swift`
uses), RainViewer (free for personal/educational use only — not licensed for
a published app).

**Accessibility angle:** This is the image that started your experiment. A
vision-language model can describe the color bands, the location of storm
cells, and whether the field is clear or active — exactly the information a
sighted user gets at a glance.

### 2. Radar Velocity (storm rotation)

A radar can also measure the *speed* of the precipitation particles moving
toward or away from the dish (Doppler shift). This is called base velocity,
and it is the image meteorologists use to spot rotation inside a thunderstorm
— the signature of a possible tornado. Green shades mean particles moving
toward the radar; red shades mean particles moving away. When you see green
and red tightly pressed together (a "couplet"), that is rotation.

**What it answers:** Is there rotation? Is the storm spinning? This is the
image that triggers tornado warnings.

**Free sources:** NWS RIDGE serves velocity products (e.g. `KMKX_V0.gif`),
and the IEM tile service has a velocity composite. The same NWS radar
stations that produce reflectivity also produce velocity.

**Accessibility angle:** This is a harder image for a vision model to
describe well because the meaning is in the *spatial relationship* of green
and red, not just the presence of color. But it is a fascinating experiment:
can the model identify a couplet and say "possible rotation near
Milwaukee"? For a screen-reader user, that is life-safety information.

### 3. Satellite Imagery (visible, infrared, water vapor)

Satellites look *down* at the clouds from space. There are three main
flavors, and they answer very different questions:

- **Visible satellite** — what the clouds look like if you were floating
  above them in space. It shows cloud tops, cloud texture, and the shape of
  weather systems. It only works during daytime (it is literally reflected
  sunlight). A forecaster looking at a visible image can spot cumulus towers
  building, the spiral of a hurricane, or the flat gray sheet of stratus.

- **Infrared (IR) satellite** — measures the *temperature* of the cloud
  tops. Since temperature drops with altitude in the troposphere, colder
  tops mean taller clouds, which mean deeper storms. IR works at night
  (it does not need sunlight), which makes it the 24-hour workhorse. The
  color scheme is usually grayscale or enhanced with false color: bright
  white = very cold, very tall cloud tops (severe storm); dark gray = warm
  low clouds or clear ground.

- **Water vapor satellite** — shows the amount of moisture in the
  mid-to-upper atmosphere. It reveals the large-scale flow patterns — dry
  slots, moisture plumes, atmospheric rivers — that steer storms. It looks
  like a swirling brown-and-green abstraction. Most users never see it, but
  it is one of the most important images a forecaster uses.

**What they answer:** Where are the clouds? How tall are the storm tops?
Where is the moisture flowing?

**Free sources:** NOAA GOES Imagery (GOES-East and GOES-West) is public
domain. The NWS hosts static images and an API. The College of DuPage
weather lab (`weather.cod.edu`) serves free GOES imagery tiles. NOAA's
STAR center has a public image server. For a published app, GOES is the
safe, free, public-domain choice — the same legal posture as NEXRAD.

**Accessibility angle:** Satellite images are rich with spatial
information — the shape of a storm system, the size of a clear area, the
spiral of a hurricane. A vision model describing a visible satellite image
could say "a large spiral of bright clouds covers the Gulf of Mexico,
centered on a distinct eye — this is a hurricane." That is exactly the kind
of gestalt that a screen-reader user currently cannot get from any weather
app. This is the most promising next experiment after radar.

### 4. Surface Analysis / Weather Maps

These are the classic "weather maps" with high and low pressure centers,
fronts (cold, warm, occluded, stationary), isobars (lines of equal
pressure), and station models. They are drawn (not photographed) from
observations. The NWS Weather Prediction Center (WPC) publishes them every
few hours as images.

**What they answer:** What is the large-scale pressure pattern? Where are
the fronts? What airmass is moving in?

**Free sources:** NWS WPC surface analysis maps (`wpc.ncep.noaa.gov`) are
public domain, served as PNG images on a fixed schedule.

**Accessibility angle:** These maps are dense with symbols — triangles on
cold fronts, semicircles on warm fronts, H and L for pressure centers. A
vision model can read these symbols and describe the pressure pattern in
plain language: "A cold front extends from a low pressure center over Iowa
southeastward through Illinois. High pressure is building in from the
Plains." For a screen-reader user, this is the kind of big-picture context
that no app currently provides in text form.

### 5. Forecast Maps (model output)

Numerical weather prediction models (GFS, NAM, HRRR, ECMWF) produce
gridded forecasts of temperature, wind, precipitation, and many other
variables. These are often rendered as maps — a temperature contour map,
a wind barb map, a precipitation accumulation map. They show what the
model *thinks* will happen, not what is happening now.

**What they answer:** What will conditions be like in 6, 12, 48 hours?

**Free sources:** NWS serves many model-output images. The College of
DuPage and NOAA's HRRR model pages serve free forecast maps. Open-Meteo
gives you the *numeric* data behind these maps (which is what WeatherFast
already uses), but the rendered images are also available.

**Accessibility angle:** Less compelling for the AI-description experiment
because WeatherFast already has the numeric forecast data and presents it
accessibly in text. The rendered map image is mostly a visualization of
data the app already has. Lower priority, but worth a test to see if the
model can describe a temperature gradient or a wind pattern in a way that
adds value over the raw numbers.

### 6. Lightning Maps

Lightning detection networks (Vaisala GLD, Earth Networks, Blitzortung)
produce maps of where lightning strikes have occurred in the last few
minutes to hours. These are usually dot maps or density maps — each dot
is a strike, or the color shows strike density.

**What they answer:** Where is lightning happening right now? Is it near
me?

**Free sources:** Blitzortung has a public real-time map (community
project). Vaisala's free `lightningmaps.org` shows real-time strikes. The
NWS does not serve a free lightning image product directly, but some
regional networks do.

**Accessibility angle:** Lightning is a safety-critical, highly localized
phenomenon. A vision model describing a lightning map could say "a cluster
of recent strikes is concentrated about 15 miles to your southwest, moving
northeast." That is exactly the kind of "is it heading at me?" question
that WeatherFast's Storm Approach feature tries to answer with numeric
data — but the image is a different, complementary source.

### 7. Hurricane / Tropical Tracking Maps

During hurricane season, the NHC (National Hurricane Center) publishes
tracking maps showing the storm's current position, its forecast track
(the "cone of uncertainty"), and watches/warnings. These are drawn maps
with a distinctive cone shape.

**What they answer:** Where is the storm, where is it going, and how
certain are we?

**Free sources:** NHC publishes these as public-domain images on a fixed
schedule during active storms.

**Accessibility angle:** The cone of uncertainty is a visual concept that
is very hard to convey in text. A vision model could describe it: "The
storm center is currently off the Florida coast. The forecast cone extends
northwestward, with the center track near Tampa in 48 hours. The cone
widens over time, reflecting growing uncertainty." This is a high-value
experiment for hurricane-season accessibility.

### 8. Temperature / Precipitation Observation Maps

These are maps of *observed* (not forecast) conditions — gridded
temperature, precipitation accumulation, snow depth. They are built from
station observations and radar-derived estimates. The NWS and NOAA
publish these as images.

**What they answer:** What actually happened? How much rain fell? How
cold did it get?

**Free sources:** NWS MRMS (Multi-Radar/Multi-Sensor) serves
precipitation accumulation images. NOAA has temperature and snow maps.

**Accessibility angle:** Lower priority for the AI experiment because
WeatherFast already fetches numeric observations (the current-conditions
data QuickRadar now pulls). But a 24-hour precipitation accumulation map
is a nice visual summary that a model could describe: "The heaviest rain
in the last 24 hours — over 3 inches — fell in a band from Madison
southwest to Dubuque."

---

## Part Two — How Weather Images Differ: Tiles, Composites, Single-Station, and More

You asked about tiles and the different kinds of radar images. This is an
important topic because the *format* of the image affects what you can do
with it, how you fetch it, and how well a vision model can describe it.

### Single-Station vs. Composite

A weather radar station (like KMKX in Milwaukee) is a single dish that
scans the sky around it out to about 143 nautical miles (about 230 km).
The image it produces is a circular sweep centered on the station — this
is a **single-station** or **base** product. The NWS RIDGE GIF that
QuickRadar downloads (`KMKX_0.gif`) is a single-station base reflectivity
image. It shows what one radar sees.

A **composite** image stitches together the output of many radar stations
into one seamless national (or regional) map. The IEM NEXRAD N0Q composite
that WeatherFast's `RadarTileService` uses is a composite — it merges all
~160 NEXRAD stations in the continental US into one image. Composites are
what you see on TV and in most weather apps because they show the whole
picture without the circular edges of individual radars.

**Key difference for your experiment:** A single-station image is a
small, fixed-size GIF (typically 600×600 pixels, under 50 KB). It is easy
to download in one HTTP request and send directly to a vision model. A
composite is enormous — a full national radar image would be tens of
megabytes — so it is almost always served as *tiles* (see below), which
means you never get one single image file; you get many small square
images that a map view assembles.

**For QuickRadar:** you are using single-station images, which is the
right choice for a "describe this one image" experiment. If you wanted to
describe a composite, you would need to either (a) render the tiles into
one image yourself, or (b) find a source that serves a pre-rendered
regional composite as a single image (the NWS does serve some regional
composites as single PNGs).

### Tiles (XYZ / slippy-map tiles)

"Tiles" are the technology behind every online map — Google Maps, Apple
Maps, WeatherFast's radar overlay. The idea is simple: instead of one
giant image, the map is cut into small square images (usually 256×256
pixels) arranged in a grid. The grid is organized by **zoom level** (z):
at z=0 there is one tile covering the whole world; at z=1 there are 4
tiles (2×2); at z=2 there are 16 (4×4); and so on, doubling in each
direction. Each tile is identified by `(z, x, y)` — zoom, column, row.

The URL pattern is always:
```
https://server/path/{z}/{x}/{y}.png
```

WeatherFast's radar overlay uses exactly this:
```
https://mesonet.agron.iastate.edu/cache/tile.py/1.0.0/nexrad-n0q-900913/{z}/{x}/{y}.png
```

MapKit (via `MKTileOverlay`) handles fetching only the tiles visible in
the current view, at the current zoom. The user never sees "a radar
image" — they see a map with radar tiles painted on top.

**Why this matters for your experiment:** You cannot send "the radar
overlay" to a vision model because there is no single image — there are
dozens of 256×256 tiles. To run the AI-description experiment on a tiled
product, you would need to:

1. Determine the bounding box of interest (e.g. a 200×200 km area around
   the user).
2. Calculate which tiles cover that area at a chosen zoom level.
3. Download each tile.
4. Stitch them together into one image (Pillow in Python, or
   UIGraphicsImageRenderer on iOS).
5. Send the stitched image to the model.

This is more work than the single-station approach, but it is the only
way to get an AI description of a composite product. It is also the path
to making WeatherFast's existing radar overlay accessible — you could
stitch the visible tiles and let VoiceOver's image recognition (or your
own Ollama call) describe them.

### Base Products vs. Derived Products

A single radar station produces a family of products from the same scan.
The NWS names them with a product code:

- **N0R / N0Q** — base reflectivity. This is "where is the precipitation
  and how intense." N0R is the older 4-bit product; N0Q is the newer
  8-bit super-resolution product. This is what QuickRadar downloads (the
  `_0.gif` is the N0R/N0Q base reflectivity).

- **N0V / N0S** — base velocity. This is the Doppler speed product
  (rotation detection) described above.

- **N1P** — one-hour precipitation accumulation. This is a derived
  product: the radar estimates how much rain has fallen in the last hour
  based on the reflectivity returns. It is a map of rainfall totals, not
  current intensity.

- **NCR** — composite reflectivity. This takes the *highest* reflectivity
  found at any altitude in each column and projects it to the ground. It
  can show storms that the base (lowest-elevation) scan misses because
  the beam overshoots them at long range.

- **N0L** — base reflectivity at a higher elevation angle. Useful for
  seeing the *structure* of a storm above the ground — the tilt of the
  echo, which indicates storm strength.

Each of these is a different image answering a different question. For
your experiment, base reflectivity (N0Q) is the obvious starting point.
Velocity (N0V) is the most interesting second experiment because it
targets tornado detection — a safety-critical use case where a good text
description could genuinely save lives.

### Static Images vs. Loops (Animation)

Everything above has been about *static* images — one frame. But the most
iconic weather image experience is the **radar loop**: a 10-frame
animation showing the last hour of precipitation, so you can see the
storm *moving*. This is what a sighted user glances at to answer "is it
coming toward me?"

**How loops work:** The NWS and IEM serve each frame as a separate image
(timestamped). A client (web page, app) fetches 8–12 frames and cycles
through them. RainViewer's API is built around this — it gives you a list
of timestamps, and you fetch each frame.

**The accessibility problem:** A loop is inherently a visual, temporal
experience. A single static frame cannot tell you about motion. This is
exactly the gap that WeatherFast's Storm Approach feature addresses with
*numeric* data (sampling precipitation at a ring of points and computing
motion). But there is an interesting AI experiment here too: you could
send *two* frames (15 minutes apart) to a vision model and ask "compare
these two radar images. Has the precipitation moved? In which direction?
Has it intensified or weakened?" Some vision models can handle
multi-image input and reason about change between frames. This would be
a genuinely novel accessibility experiment — turning animation into text.

### Resolution and Range

A single NEXRAD station has a maximum range of about 143 nautical miles
(230 km). Beyond that, the Earth's curvature blocks the beam at low
altitudes, and the beam has risen so high that it overshoots most
precipitation. This is why composites exist — to fill in the gaps between
stations.

The super-resolution NEXRAD products (N0Q) have a resolution of about
250 meters near the station, degrading with distance. The older N0R
products are about 1 km. For your experiment, the resolution is more than
adequate — a vision model can easily distinguish storm cells in a 600×600
pixel image covering a 460 km diameter area.

### Summary Table: Image Types and How to Get Them

| Image type | Single image? | Free public-domain source | Best for AI experiment? |
|---|---|---|---|
| Base reflectivity (N0Q) | Yes (single-station GIF) | NWS RIDGE, IEM tiles | ✅ Already doing this |
| Base velocity (N0V) | Yes (single-station GIF) | NWS RIDGE | ✅ High value — tornado rotation |
| Composite reflectivity | Tiles only | IEM NEXRAD tiles | Needs stitching first |
| Visible satellite | Yes (per-region PNG) | NOAA GOES, College of DuPage | ✅ High value — cloud shapes |
| Infrared satellite | Yes (per-region PNG) | NOAA GOES | ✅ Works at night |
| Water vapor satellite | Yes (per-region PNG) | NOAA GOES | Medium — abstract |
| Surface analysis | Yes (drawn PNG) | NWS WPC | ✅ High value — fronts/pressure |
| Forecast maps | Yes (PNG) | NWS, College of DuPage | Lower — app has numeric data |
| Lightning maps | Yes (PNG/HTML) | Blitzortung, lightningmaps.org | Medium — safety critical |
| Hurricane track maps | Yes (drawn PNG) | NHC | ✅ High value in hurricane season |
| Precip accumulation | Yes (PNG) | NWS MRMS | Lower — app has numeric data |

---

## Part Three — What This Means for WeatherFast

Your QuickRadar experiment is the prototype for a broader strategy. The
insight is simple but powerful: **every weather image that a sighted user
glances at is a candidate for AI description.** WeatherFast's
accessibility-first mission means that if the app ever shows an image, it
should also be able to describe that image in text.

Here is how the image types above map onto WeatherFast's current and
planned features:

### What WeatherFast already has

- **Radar tile overlay** (`RadarTileService.swift`, `RadarMapView.swift`)
  — NEXRAD composite tiles via IEM, shown on a MapKit overlay. This is
  the image that VoiceOver image recognition can already describe on iOS
  26/27, and the image you could stitch and send to Ollama for a richer
  description.

- **Storm Approach** (`StormApproachService.swift`) — the *numeric*
  radar replacement. It samples precipitation at a ring of points and
  computes storm motion, then narrates "rain to the southwest, reaching
  you in 25 minutes." This is the text-first approach; the AI image
  description is the image-first complement.

- **Next Hour narration** (`RadarService.buildNextHourSummary`) — the
  Dark-Sky-style "rain starting in 11 minutes" sentence. This is pure
  numeric data, no image involved.

### What the experiment could unlock

The QuickRadar methodology — download image, send to vision model, get
text description, compare against numeric ground truth — generalizes to
every image type in the table above. The most promising next experiments,
in priority order:

1. **Radar velocity (N0V)** — can the model identify rotation? This is
   the tornado-detection use case. If a vision model can reliably say
   "there is a tight rotation couplet 20 miles southwest of your
   location," that is life-safety information no weather app currently
   delivers in text.

2. **Visible/IR satellite** — can the model describe the shape and
   extent of cloud systems? "A large comma-shaped cloud mass covers the
   Upper Midwest, with a clear dry slot punching into Iowa." This is the
   big-picture context that satellite imagery provides and that no app
   currently makes accessible.

3. **Surface analysis** — can the model read the symbols (fronts,
   pressure centers) and describe the synoptic pattern? This is the
   "weather 101" image that every forecaster uses and that no app
   translates to text.

4. **Two-frame radar comparison** — send two frames 15 minutes apart and
   ask the model to describe motion. This turns the radar loop — the
   most iconic weather animation — into an accessible narrative. It
   directly validates (or challenges) Storm Approach's numeric
   direction estimate.

### The two-track strategy

WeatherFast is already pursuing two complementary tracks for
non-visual weather:

- **Track A — Numeric first (Storm Approach, Next Hour):** compute
  direction, timing, and intensity from API data and narrate it in plain
  language. This is reliable, deterministic, and works everywhere. It is
  the backbone.

- **Track B — Image description (QuickRadar, VoiceOver recognition):**
  take the actual image that sighted users see and describe it with AI.
  This is complementary — it captures the *gestalt* (the shape, the
   spatial pattern, the "feel" of the weather) that numbers alone cannot
   convey. It is also a ground-truth check on Track A: does the image
   description agree with the numeric narration?

The two tracks validate each other. When Storm Approach says "moving
northeast at 25 mph" and the image description says "a line of storms
extends from Madison southwestward, with the heaviest cells moving
northeast," you have high confidence. When they disagree, you have a
signal to investigate — either the numeric estimate is wrong, or the
model misread the image. That cross-check is the real value of running
both.

---

## Part Four — Practical Next Steps for the Experiment

If you want to extend QuickRadar beyond base reflectivity, here is how:

### Velocity images (tornado rotation)

The NWS RIDGE URL pattern is the same as reflectivity, just with a
different product suffix. For station KMKX:
```
https://radar.weather.gov/ridge/standard/KMKX_V0.gif
```
The `_V0` is base velocity. You could add a `--product` flag to QuickRadar
and download velocity alongside reflectivity, then ask the model a
different prompt: "This is a Doppler velocity image. Green means moving
toward the radar, red means away. Look for areas where green and red are
adjacent — that indicates rotation. Describe any rotation you see and
its location."

### Satellite images

NOAA GOES imagery is served as static images per region. The College of
DuPage (`weather.cod.edu`) has a convenient interface. For a simple
experiment, you can fetch a regional GOES-East visible image as a single
PNG and send it to the model. The prompt would be: "This is a visible
satellite image showing clouds from space. Describe the cloud patterns,
their shape, extent, and any notable features like spirals, lines, or
clear areas."

### Two-frame comparison

Download two radar images 15 minutes apart (the NWS serves timestamped
frames; the IEM API can list available timestamps). Send both to a
multi-image-capable model and ask: "Here are two radar images 15 minutes
apart. Describe what has changed: has the precipitation moved, in which
direction, and has it intensified or weakened?"

### Stitching tiles for composite description

If you want to describe the composite radar (what WeatherFast's overlay
shows), you would use Python's Pillow library to download the relevant
tiles at a chosen zoom level and stitch them into one image. The math
for converting lat/lon + zoom to tile x/y is well-documented (the
"slippy map tilenames" formula). This is more engineering effort but
unlocks the ability to describe exactly what the app's map overlay
shows.

---

## Closing

The experiment you are running with QuickRadar is small in code but
large in implication. You are proving that a vision-language model can
take a weather image — the kind of image that has always been
inaccessible to screen-reader users — and turn it into a detailed,
objective text description. If that works reliably for radar
reflectivity, it can work for velocity, satellite, surface analysis,
and every other image type that weather apps show.

WeatherFast's mission is to make weather accessible. The numeric track
(Storm Approach, Next Hour) is the reliable backbone. The image track
(QuickRadar, AI description) is the complement that captures the gestalt.
Together, they close the gap that has always existed between the
sighted user glancing at a radar and the non-sighted user hearing a
forecast.

The next sunny day ahead is the one where a blind user can ask "what's
on the radar?" and get an answer as rich and immediate as the picture
itself.

---

*This document was prepared as an educational reference for Kelly Ford,
the innovator behind WeatherFast's accessibility strategy. It is grounded
in a review of the WeatherFast codebase (iOS branch and nowcasting
proposal), the NWS/NOAA public-domain data ecosystem, and the current
state of vision-language models. All data sources mentioned are free
and public-domain unless otherwise noted.*

*WeatherFast repository: `c:\users\kelly\github\fastweather`*
*QuickRadar experiment: `c:\users\kelly\github\quickradar`*