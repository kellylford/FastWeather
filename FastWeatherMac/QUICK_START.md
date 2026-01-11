# Quick Start: Building and Launching FastWeather Mac App

## TL;DR - Three Simple Commands

```bash
cd /Users/kellyford/Documents/GitHub/FastWeather/FastWeatherMac
./build-and-launch.sh
```

That's it! The app will build and launch automatically.

---

## Individual Commands

### Just Build
```bash
./build-app.sh
```

### Just Launch (after building)
```bash
./launch-app.sh
```

### Build Debug Version
```bash
./build-app.sh Debug
```

---

## Opening from Finder

After building once, you can find the app at:
```
FastWeatherMac/build/Build/Products/Release/FastWeatherMac.app
```

**To create a desktop shortcut:**
1. Build the app first
2. Navigate to the build location in Finder
3. Right-click `FastWeatherMac.app` → "Make Alias"
4. Drag the alias to your Desktop

**To add to Dock:**
1. Launch the app
2. Right-click the app icon in Dock
3. Options → Keep in Dock

---

## What Each Script Does

| Script | Purpose |
|--------|---------|
| `build-app.sh` | Compiles the app using Xcode command line tools |
| `launch-app.sh` | Opens the built app |
| `build-and-launch.sh` | Builds and then launches the app |

---

## First Time Setup

**Important:** Add the city data files to Xcode project:

1. Open `FastWeatherMac.xcodeproj` in Xcode
2. Right-click in Project Navigator → "Add Files to 'FastWeatherMac'..."
3. Select these files:
   - `us-cities-cached.json`
   - `international-cities-cached.json`
4. Check "Copy items if needed"
5. Check "Add to targets: FastWeatherMac"
6. Click "Add"

Without this step, the state/country browsing feature won't work!

---

## Troubleshooting

**"App not found"**
→ Build it first: `./build-app.sh`

**"Build failed"**
→ Open the project in Xcode to see detailed errors

**"Missing city data"**
→ Add the JSON files to Xcode project (see First Time Setup above)

**"Permission denied"**
→ Make scripts executable: `chmod +x *.sh`

---

## Need More Help?

See the complete documentation: [BUILD_SCRIPTS_README.md](BUILD_SCRIPTS_README.md)
