"""Builds the CURRENT / HOURLY / DAILY text report for the detailed view.

Ported verbatim from the monolith's format_full_weather so output is identical.
Pure text: takes parsed API data, the AppSettings (field toggles), and a
Formatter (unit-aware). Returns a list of lines for AccessibleLinesPanel.
"""

from datetime import datetime

from ..models.weather import describe_cloud_cover, describe_weather_code


def _duration_hours(seconds):
    """Format a duration in seconds as 'Xh Ym'."""
    total_min = int(round(seconds / 60))
    h, m = divmod(total_min, 60)
    return f"{h}h {m}m"


def _hour_ampm(iso):
    """'2026-07-22T15:00' -> '3 PM'."""
    dt = datetime.strptime(iso, "%Y-%m-%dT%H:%M")
    return dt.strftime("%I %p").lstrip("0")


def build_today_outlook(data, settings, fmt):
    """Plain-language highlights for today (precip timing, UV, wind)."""
    lines = []
    hourly = data.get("hourly", {})
    daily = data.get("daily", {})
    curr = data.get("current", {})
    times = hourly.get("time", [])
    probs = hourly.get("precipitation_probability", [])
    ctime = curr.get("time")
    today = (ctime or (times[0] if times else ""))[:10]

    # Precipitation timing: longest run of hours today (>= now) with prob >= 50%.
    best = None
    run = None
    for i, t in enumerate(times):
        if not t.startswith(today):
            continue
        if ctime and t < ctime:
            continue
        p = probs[i] if i < len(probs) else None
        if p is not None and p >= 50:
            if run is None:
                run = [i, i, p]
            else:
                run[1], run[2] = i, max(run[2], p)
        elif run is not None:
            if best is None or (run[1] - run[0]) > (best[1] - best[0]):
                best = run
            run = None
    if run is not None and (best is None or (run[1] - run[0]) > (best[1] - best[0])):
        best = run
    if best is not None:
        s, e, peak = best
        span = _hour_ampm(times[s]) if s == e else f"{_hour_ampm(times[s])}-{_hour_ampm(times[e])}"
        lines.append(f"Precipitation most likely {span} ({peak}% chance)")

    # UV and wind alerts from today's daily values.
    uv = (daily.get("uv_index_max") or [None])[0]
    if uv is not None and uv >= 6:
        lines.append(f"High UV today (max {uv:.0f})")
    wind = (daily.get("windspeed_10m_max") or [None])[0]
    if wind is not None and wind >= 40:  # ~25 mph
        lines.append(f"Breezy today (up to {fmt.wind_speed(wind)})")
    return lines


def build_day_lines(city, data, settings, fmt, target_date, offset_label):
    """Render a specific day's hourly + summary (for date navigation)."""
    lines = [f"Weather for {city}", f"{target_date} ({offset_label})", "=" * 40]

    daily = data.get("daily", {})
    dtimes = daily.get("time", [])
    if target_date in dtimes:
        idx = dtimes.index(target_date)
        # Build a compact summary line for the day.
        summary = [f"{datetime.strptime(target_date, '%Y-%m-%d').strftime('%a %b %d')}:"]
        mx = (daily.get("temperature_2m_max") or [None] * (idx + 1))[idx]
        mn = (daily.get("temperature_2m_min") or [None] * (idx + 1))[idx]
        if mx is not None:
            summary.append(f"High {fmt.temperature_short(mx)}")
        if mn is not None:
            summary.append(f"Low {fmt.temperature_short(mn)}")
        ps = (daily.get("precipitation_sum") or [None] * (idx + 1))[idx]
        if ps:
            summary.append(f"{fmt.precipitation(ps)} precip")
        code = (daily.get("weathercode") or [None] * (idx + 1))[idx]
        desc = describe_weather_code(code)
        if desc:
            summary.append(desc)
        lines.append("SUMMARY")
        lines.append(" ".join(summary))
        lines.append("")

    # Hourly for the target day.
    hourly = data.get("hourly", {})
    htimes = hourly.get("time", [])
    temps = hourly.get("temperature_2m", [])
    precip = hourly.get("precipitation", [])
    probs = hourly.get("precipitation_probability", [])
    lines.append("HOURLY")
    for i, t in enumerate(htimes):
        if not t.startswith(target_date):
            continue
        when = datetime.strptime(t, "%Y-%m-%dT%H:%M").strftime("%I:%M %p")
        parts = [f"{when}:"]
        if i < len(temps) and temps[i] is not None:
            parts.append(fmt.temperature_short(temps[i]))
        if i < len(probs) and probs[i]:
            parts.append(f"{probs[i]}% chance")
        if i < len(precip) and precip[i]:
            parts.append(f"{fmt.precipitation(precip[i])} precip")
        lines.append(" ".join(parts))
    lines.append("")
    lines.append("Data by Open-Meteo.com (CC BY 4.0)")
    return lines


def build_full_weather_lines(city, data, settings, fmt):
    lines = []
    lines.append(f"Report for {city}")
    lines.append("=" * 40)

    curr = data.get("current", data.get("current_weather", {}))
    hourly = data.get("hourly", {})
    daily = data.get("daily", {})

    cfg_curr = settings["current"]
    if curr:
        lines.append("CURRENT")

        def get_val(keys, default=0):
            if isinstance(keys, str):
                keys = [keys]
            for k in keys:
                if k in curr and curr[k] is not None:
                    return curr[k]
            return default

        if cfg_curr.get("condition", True):
            code = get_val(["weather_code", "weathercode"], None)
            desc = describe_weather_code(code)
            if desc:
                lines.append(f"Condition: {desc}")

        if cfg_curr.get("temperature", True):
            temp_c = get_val(["temperature_2m", "temperature"])
            lines.append(f"Temp: {fmt.temperature(temp_c)}")

        if cfg_curr.get("feels_like", False):
            app_temp_c = get_val(["apparent_temperature"])
            lines.append(f"Feels Like: {fmt.temperature(app_temp_c)}")

        if cfg_curr.get("humidity", False):
            hum = get_val(["relative_humidity_2m"])
            lines.append(f"Humidity: {hum}%")

        if cfg_curr.get("dew_point", False):
            dp = get_val(["dewpoint_2m", "dew_point_2m"], None)
            if dp is not None:
                lines.append(f"Dew Point: {fmt.temperature(dp)}")

        if cfg_curr.get("pressure", False):
            pres = get_val(["pressure_msl", "surface_pressure"])
            lines.append(f"Pressure: {fmt.pressure(pres)}")

        if cfg_curr.get("visibility", False):
            vis_m = get_val(["visibility"])
            lines.append(f"Visibility: {fmt.distance(vis_m)}")

        if cfg_curr.get("uv_index", False):
            uv = get_val(["uv_index"])
            if uv == 0 and hourly and "uv_index" in hourly and "time" in hourly:
                curr_time = curr.get("time")
                if curr_time in hourly["time"]:
                    idx = hourly["time"].index(curr_time)
                    uv = hourly["uv_index"][idx]
            lines.append(f"UV Index: {uv}")

        if cfg_curr.get("precipitation", False):
            precip = get_val(["precipitation"])
            if precip > 0:
                lines.append(f"Precipitation: {fmt.precipitation(precip)}")

        if cfg_curr.get("cloud_cover", False):
            cc = get_val(["cloud_cover", "cloudcover"])
            if cc is not None:
                desc = describe_cloud_cover(cc).title()
                lines.append(f"Cloud Cover: {cc}% ({desc})")

        if cfg_curr.get("snowfall", False):
            snow = get_val(["snowfall"])
            if snow >= 0.01:
                lines.append(f"Snowfall: {fmt.precipitation(snow)}")
            elif snow == 0:
                lines.append("Snowfall: None")

        if cfg_curr.get("snow_depth", False):
            depth = get_val(["snow_depth"])
            if depth >= 0.01:
                depth_converted = depth * 1000  # meters -> mm for consistency
                lines.append(f"Snow Depth: {fmt.precipitation(depth_converted)}")
            elif depth == 0:
                lines.append("Snow Depth: None")

        if cfg_curr.get("rain", False):
            rain = get_val(["rain"])
            if rain >= 0.01:
                lines.append(f"Rain: {fmt.precipitation(rain)}")
            elif rain == 0:
                lines.append("Rain: None")

        if cfg_curr.get("showers", False):
            showers = get_val(["showers"])
            if showers >= 0.01:
                lines.append(f"Showers: {fmt.precipitation(showers)}")
            elif showers == 0:
                lines.append("Showers: None")

        if cfg_curr.get("wind_speed", True):
            wind_kmh = get_val(["wind_speed_10m", "windspeed"])
            wind_dir = get_val(["wind_direction_10m", "winddirection"])
            wind_card = fmt.cardinal(wind_dir)
            if cfg_curr.get("wind_direction", True):
                lines.append(
                    f"Wind: {fmt.wind_speed(wind_kmh)} {wind_card} ({wind_dir}°)"
                )
            else:
                lines.append(f"Wind: {fmt.wind_speed(wind_kmh)}")
        elif cfg_curr.get("wind_direction", True):
            wind_dir = get_val(["wind_direction_10m", "winddirection"])
            wind_card = fmt.cardinal(wind_dir)
            lines.append(f"Wind Dir: {wind_card} ({wind_dir}°)")

        if cfg_curr.get("wind_gusts", False):
            gust = get_val(["wind_gusts_10m", "windgusts_10m"], None)
            if gust is not None:
                lines.append(f"Wind Gusts: {fmt.wind_speed(gust)}")

        lines.append("")

        if settings["current"].get("today_outlook", True):
            outlook = build_today_outlook(data, settings, fmt)
            if outlook:
                lines.append("TODAY'S OUTLOOK")
                lines.extend(outlook)
                lines.append("")

    cfg_hourly = settings["hourly"]
    if hourly and any(cfg_hourly.values()):
        lines.append("HOURLY")
        times = hourly.get("time", [])
        temps = hourly.get("temperature_2m", [])
        app_temps = hourly.get("apparent_temperature", [])
        precip = hourly.get("precipitation", [])
        humidity = hourly.get("relative_humidity_2m", [])
        wind_speeds = hourly.get("windspeed_10m", [])
        wind_dirs = hourly.get("winddirection_10m", [])
        cloud_cover = hourly.get("cloudcover", [])
        snowfall = hourly.get("snowfall", [])
        rain = hourly.get("rain", [])
        showers = hourly.get("showers", [])
        codes = hourly.get("weathercode", [])
        dewpoints = hourly.get("dewpoint_2m", [])
        precip_prob = hourly.get("precipitation_probability", [])
        gusts = hourly.get("windgusts_10m", [])

        start = 0
        curr_time = curr.get("time") if curr else None
        if curr_time and times:
            try:
                curr_dt = datetime.strptime(curr_time, "%Y-%m-%dT%H:%M")
                first_dt = datetime.strptime(times[0], "%Y-%m-%dT%H:%M")
                diff_seconds = (curr_dt - first_dt).total_seconds()
                idx = round(diff_seconds / 3600)
                if 0 <= idx < len(times):
                    start = idx
            except Exception:
                pass

        for i in range(start, min(start + 24, len(times))):
            parts = []
            t = datetime.strptime(times[i], "%Y-%m-%dT%H:%M").strftime("%I:%M %p")
            parts.append(f"{t}:")

            if cfg_hourly.get("temperature", True) and i < len(temps) and temps[i] is not None:
                parts.append(fmt.temperature_short(temps[i]))

            if cfg_hourly.get("feels_like", False) and i < len(app_temps) and app_temps[i] is not None:
                parts.append(f"Feels Like {fmt.temperature_short(app_temps[i])}")

            if cfg_hourly.get("condition", False) and i < len(codes) and codes[i] is not None:
                desc = describe_weather_code(codes[i])
                if desc:
                    parts.append(desc)

            if cfg_hourly.get("dew_point", False) and i < len(dewpoints) and dewpoints[i] is not None:
                parts.append(f"Dew {fmt.temperature_short(dewpoints[i])}")

            if cfg_hourly.get("precip_probability", False) and i < len(precip_prob) and precip_prob[i] is not None:
                parts.append(f"{precip_prob[i]}% chance")

            if cfg_hourly.get("precipitation", True) and i < len(precip) and precip[i] is not None:
                p = precip[i]
                if p > 0:
                    parts.append(f"{fmt.precipitation(p)} precip")

            if cfg_hourly.get("humidity", True) and i < len(humidity) and humidity[i] is not None:
                parts.append(f"Humidity {humidity[i]}%")

            if cfg_hourly.get("cloud_cover", False) and i < len(cloud_cover) and cloud_cover[i] is not None:
                cc = cloud_cover[i]
                desc = describe_cloud_cover(cc).title()
                parts.append(f"{desc} ({cc}%)")

            if cfg_hourly.get("snowfall", False) and i < len(snowfall) and snowfall[i] is not None:
                s = snowfall[i]
                if s >= 0.01:
                    parts.append(f"{fmt.precipitation(s)} snow")

            if cfg_hourly.get("rain", False) and i < len(rain) and rain[i] is not None:
                r = rain[i]
                if r >= 0.01:
                    parts.append(f"{fmt.precipitation(r)} rain")

            if cfg_hourly.get("showers", False) and i < len(showers) and showers[i] is not None:
                sh = showers[i]
                if sh >= 0.01:
                    parts.append(f"{fmt.precipitation(sh)} showers")

            if cfg_hourly.get("wind_speed", False) and i < len(wind_speeds) and wind_speeds[i] is not None:
                parts.append(fmt.wind_speed(wind_speeds[i]))

            if cfg_hourly.get("wind_direction", False) and i < len(wind_dirs) and wind_dirs[i] is not None:
                parts.append(f"{fmt.cardinal(wind_dirs[i])}")

            if cfg_hourly.get("wind_gusts", False) and i < len(gusts) and gusts[i] is not None:
                parts.append(f"gust {fmt.wind_speed(gusts[i])}")

            lines.append(" ".join(parts))
        lines.append("")

    cfg_daily = settings["daily"]
    if daily and any(cfg_daily.values()):
        lines.append("DAILY")
        times = daily.get("time", [])
        maxs = daily.get("temperature_2m_max", [])
        mins = daily.get("temperature_2m_min", [])
        precip_sum = daily.get("precipitation_sum", [])
        precip_hours = daily.get("precipitation_hours", [])
        wind_maxs = daily.get("windspeed_10m_max", [])
        wind_doms = daily.get("winddirection_10m_dominant", [])
        sunrise = daily.get("sunrise", [])
        sunset = daily.get("sunset", [])
        snowfall_sum = daily.get("snowfall_sum", [])
        rain_sum = daily.get("rain_sum", [])
        showers_sum = daily.get("showers_sum", [])
        codes = daily.get("weathercode", [])
        app_max = daily.get("apparent_temperature_max", [])
        app_min = daily.get("apparent_temperature_min", [])
        uv_max = daily.get("uv_index_max", [])
        daylight = daily.get("daylight_duration", [])
        sunshine = daily.get("sunshine_duration", [])
        precip_prob_max = daily.get("precipitation_probability_max", [])

        for i in range(len(times)):
            d = datetime.strptime(times[i], "%Y-%m-%d").strftime("%a %b %d")
            parts = [f"{d}:"]

            if cfg_daily.get("condition", False) and i < len(codes) and codes[i] is not None:
                desc = describe_weather_code(codes[i])
                if desc:
                    parts.append(desc)

            if cfg_daily.get("temperature_max", True) and i < len(maxs) and maxs[i] is not None:
                parts.append(f"High {fmt.temperature_short(maxs[i])}")

            if cfg_daily.get("temperature_min", True) and i < len(mins) and mins[i] is not None:
                parts.append(f"Low {fmt.temperature_short(mins[i])}")

            if cfg_daily.get("apparent_max", False) and i < len(app_max) and app_max[i] is not None:
                parts.append(f"Feels High {fmt.temperature_short(app_max[i])}")

            if cfg_daily.get("apparent_min", False) and i < len(app_min) and app_min[i] is not None:
                parts.append(f"Feels Low {fmt.temperature_short(app_min[i])}")

            if cfg_daily.get("precipitation_sum", True) and i < len(precip_sum) and precip_sum[i] is not None:
                p = precip_sum[i]
                if p > 0:
                    parts.append(f"{fmt.precipitation(p)} precip")

            if cfg_daily.get("precip_probability_max", False) and i < len(precip_prob_max) and precip_prob_max[i] is not None:
                parts.append(f"{precip_prob_max[i]}% chance")

            if cfg_daily.get("uv_max", False) and i < len(uv_max) and uv_max[i] is not None:
                parts.append(f"UV {uv_max[i]:.0f}")

            if cfg_daily.get("daylight_duration", False) and i < len(daylight) and daylight[i] is not None:
                parts.append(f"Daylight {_duration_hours(daylight[i])}")

            if cfg_daily.get("sunshine_duration", False) and i < len(sunshine) and sunshine[i] is not None:
                parts.append(f"Sunshine {_duration_hours(sunshine[i])}")

            if cfg_daily.get("precipitation_hours", False) and i < len(precip_hours) and precip_hours[i] is not None:
                ph = precip_hours[i]
                if ph > 0:
                    parts.append(f"{ph:.1f}h precip")

            if cfg_daily.get("snowfall_sum", False) and i < len(snowfall_sum) and snowfall_sum[i] is not None:
                ss = snowfall_sum[i]
                if ss >= 0.01:
                    parts.append(f"{fmt.precipitation(ss)} snow")

            if cfg_daily.get("rain_sum", False) and i < len(rain_sum) and rain_sum[i] is not None:
                rs = rain_sum[i]
                if rs >= 0.01:
                    parts.append(f"{fmt.precipitation(rs)} rain")

            if cfg_daily.get("showers_sum", False) and i < len(showers_sum) and showers_sum[i] is not None:
                shs = showers_sum[i]
                if shs >= 0.01:
                    parts.append(f"{fmt.precipitation(shs)} showers")

            if cfg_daily.get("wind_speed_max", False) and i < len(wind_maxs) and wind_maxs[i] is not None:
                parts.append(f"Max Wind {fmt.wind_speed(wind_maxs[i])}")

            if cfg_daily.get("wind_direction_dominant", False) and i < len(wind_doms) and wind_doms[i] is not None:
                parts.append(f"Wind {fmt.cardinal(wind_doms[i])}")

            if cfg_daily.get("sunrise", True) and i < len(sunrise) and sunrise[i] is not None:
                sr = datetime.strptime(sunrise[i], "%Y-%m-%dT%H:%M").strftime("%I:%M %p")
                parts.append(f"Sunrise {sr}")

            if cfg_daily.get("sunset", True) and i < len(sunset) and sunset[i] is not None:
                ss = datetime.strptime(sunset[i], "%Y-%m-%dT%H:%M").strftime("%I:%M %p")
                parts.append(f"Sunset {ss}")

            lines.append(" ".join(parts))

    lines.append("")
    lines.append("Data by Open-Meteo.com (CC BY 4.0)")
    return lines
