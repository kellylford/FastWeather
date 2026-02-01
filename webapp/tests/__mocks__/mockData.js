// Mock weather data for testing
export const mockWeatherResponse = {
  latitude: 43.07,
  longitude: -89.38,
  timezone: "America/Chicago",
  current: {
    time: "2026-02-01T12:00",
    temperature_2m: 72.5,
    apparent_temperature: 70.2,
    relative_humidity_2m: 65,
    weather_code: 0,
    cloud_cover: 25,
    pressure_msl: 1013.25,
    surface_pressure: 1010.0,
    wind_speed_10m: 10.5,
    wind_direction_10m: 180,
    wind_gusts_10m: 15.2,
    visibility: 10000,
    uv_index: 3.5,
    precipitation: 0,
    rain: 0,
    showers: 0,
    snowfall: 0,
    dewpoint_2m: 58.3,
    is_day: 1
  },
  hourly: {
    time: Array.from({ length: 24 }, (_, i) => {
      const hour = new Date();
      hour.setHours(i);
      return hour.toISOString().slice(0, 16);
    }),
    temperature_2m: Array(24).fill(72).map((t, i) => t + Math.sin(i / 4) * 5),
    apparent_temperature: Array(24).fill(70).map((t, i) => t + Math.sin(i / 4) * 5),
    relative_humidity_2m: Array(24).fill(65),
    weathercode: Array(24).fill(0),
    cloudcover: Array(24).fill(25),
    windspeed_10m: Array(24).fill(10),
    winddirection_10m: Array(24).fill(180),
    windgusts_10m: Array(24).fill(15),
    precipitation: Array(24).fill(0),
    precipitation_probability: Array(24).fill(10),
    uv_index: Array(24).fill(3).map((v, i) => i > 6 && i < 18 ? v : 0),
    dewpoint_2m: Array(24).fill(58)
  },
  daily: {
    time: Array.from({ length: 16 }, (_, i) => {
      const day = new Date();
      day.setDate(day.getDate() + i);
      return day.toISOString().slice(0, 10);
    }),
    weathercode: Array(16).fill(0),
    temperature_2m_max: Array(16).fill(75).map((t, i) => t + (i % 3)),
    temperature_2m_min: Array(16).fill(55).map((t, i) => t - (i % 3)),
    apparent_temperature_max: Array(16).fill(73),
    apparent_temperature_min: Array(16).fill(53),
    sunrise: Array(16).fill("2026-02-01T06:50"),
    sunset: Array(16).fill("2026-02-01T17:30"),
    precipitation_sum: Array(16).fill(0),
    precipitation_probability_max: Array(16).fill(10),
    windspeed_10m_max: Array(16).fill(15),
    winddirection_10m_dominant: Array(16).fill(180),
    uv_index_max: Array(16).fill(4),
    daylight_duration: Array(16).fill(38400),
    sunshine_duration: Array(16).fill(30000)
  }
};

export const mockGeocodingResponse = [
  {
    lat: "43.074761",
    lon: "-89.383761",
    display_name: "Madison, Wisconsin, United States",
    address: {
      city: "Madison",
      state: "Wisconsin",
      country: "United States"
    }
  }
];

export const mockCities = {
  "Madison, Wisconsin, United States": [43.074761, -89.383761],
  "San Diego, California, United States": [32.7174202, -117.162772]
};

export const mockConfig = {
  current: {
    temperature: true,
    feels_like: true,
    humidity: true,
    wind_speed: true,
    wind_direction: true,
    wind_gusts: false,
    uv_index: false,
    precipitation: true,
    cloud_cover: false,
    pressure: false,
    visibility: false,
    dew_point: false
  },
  hourly: {
    temperature: true,
    feels_like: false,
    humidity: false,
    precipitation: true,
    precipitation_probability: true,
    wind_speed: false,
    wind_direction: false,
    wind_gusts: false,
    uv_index: false,
    cloud_cover: false,
    dew_point: false
  },
  daily: {
    temperature_max: true,
    temperature_min: true,
    sunrise: true,
    sunset: true,
    precipitation_sum: true,
    precipitation_probability: true,
    precipitation_hours: false,
    wind_speed_max: false,
    wind_direction_dominant: false,
    uv_index_max: false,
    daylight_duration: false,
    sunshine_duration: false
  },
  cityList: {
    temperature: true,
    conditions: true,
    feels_like: false,
    humidity: true,
    wind_speed: true,
    wind_direction: false,
    wind_gusts: false,
    uv_index: false,
    high_temp: true,
    low_temp: true,
    precipitation: true,
    alerts: true
  },
  cityListOrder: ['temperature', 'conditions', 'humidity', 'wind_speed', 'high_temp', 'low_temp', 'precipitation', 'alerts'],
  units: {
    temperature: 'F',
    wind_speed: 'mph',
    precipitation: 'in',
    pressure: 'inHg',
    distance: 'mi'
  },
  defaultView: 'flat',
  listViewStyle: 'detailed',
  hourlyDetailView: 'flat',
  dailyDetailView: 'flat'
};
