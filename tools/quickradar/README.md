# QuickRadar

A small Python data-gathering script for a screen-reader-friendly weather app.
It evaluates how well a vision-language model (via [Ollama](https://ollama.com))
can describe weather radar imagery in text — useful for users who cannot see
the image.

## What it does

Given a US zipcode, QuickRadar:

1. **Geocodes** the zipcode to lat/lon using [zippopotam.us](https://www.zippopotam.us) (free, no API key).
2. **Finds the nearest NWS radar station** using the free [api.weather.gov](https://www.weather.gov/documentation/services-web-api) radar servers endpoint.
3. **Downloads** the latest base-reflectivity radar image for that station from NWS RIDGE.
4. **Sends the image to Ollama** (a local vision model such as `llava`) and asks for a detailed, objective, screen-reader-friendly description of the radar.
5. **Fetches the NWS point forecast** for the location.
6. **Writes a combined text report** containing both the AI radar description and the forecast.

All data sources are free and require no API keys.

## Requirements

- Python 3.9+
- A running [Ollama](https://ollama.com) server (default `http://localhost:11434`)
- A vision model pulled in Ollama, e.g.:

  ```bash
  ollama pull gemma4:31b-cloud
  ```

## Install

```bash
pip install -r requirements.txt
```

## Usage

```bash
# Basic usage
python quickradar.py 60601

# Choose a different vision model and output file, and delete the radar image
python quickradar.py 90210 --model llava:13b --output report.txt --no-keep-image

# Default model is gemma4:31b-cloud
python quickradar.py 60601

# Point at a non-default Ollama server
python quickradar.py 33109 --ollama-url http://myhost:11434
```

### Options

| Option          | Dgemma4:31b-cloud`       | Description                          |
|-----------------|--------------------------|--------------------------------------|
| `zipcode`       | (required)               | US zipcode, e.g. `60601`             |
| `--model`       | `llava`                  | Ollama vision model name             |
| `--ollama-url`  | `http://localhost:11434` | Ollama server URL                    |
| `--output, -o`  | `weather_<zipcode>.txt`  | Output text report path              |
| `--no-keep-image` | off                      | Delete the radar image after writing the report (kept by default) |

## Output

A text file (default `weather_<zipcode>.txt`) containing:
Ollama token usage (prompt, output, and total token counts)
- 
- Location and radar station metadata
- The Ollama-generated radar image description
- The NWS forecast for the next several periods

## Notes

- The NWS RIDGE radar image URLs occasionally change; the script tries several
  known patterns and reports a clear error if none work.
- The script is designed to keep going and still write a report even if the
  Ollama description fails, so you always get the forecast data.
- This is a research / data-gathering tool, not a production weather service.