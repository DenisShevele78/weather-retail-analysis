"""
Load Weather Data from Open-Meteo Archive API into PostgreSQL.
 
Step 5 of Weather × Retail Sales project.
Downloads daily weather data for London (Dec 2009 – Dec 2011)
and loads it into the weather_daily table.
 
API docs: https://open-meteo.com/en/docs/historical-weather-api
"""
 
import requests
import pandas as pd
from sqlalchemy import create_engine
 
 
# =============================================================
# SETTINGS — change these to match your environment
# =============================================================
 
DB_URL = "postgresql://user:password@localhost:5433/retail_weather"
engine = create_engine(DB_URL)
 
API_URL = "https://archive-api.open-meteo.com/v1/archive"
 
 
# =============================================================
# WMO WEATHER CODE MAPPINGS
# Source: https://gist.github.com/stellasphere/9490c195ed2b53c707087c8c2db4ec0c
# =============================================================
 
# WMO code → short category for weather_main column
WMO_TO_MAIN = {
    0: "Clear",     1: "Clear",
    2: "Cloudy",    3: "Cloudy",
    45: "Fog",      48: "Fog",
    51: "Drizzle",  53: "Drizzle",  55: "Drizzle",
    56: "Drizzle",  57: "Drizzle",
    61: "Rain",     63: "Rain",     65: "Rain",
    66: "Rain",     67: "Rain",
    71: "Snow",     73: "Snow",     75: "Snow",     77: "Snow",
    80: "Rain",     81: "Rain",     82: "Rain",
    85: "Snow",     86: "Snow",
    95: "Thunderstorm", 96: "Thunderstorm", 99: "Thunderstorm",
}
 
# WMO code → detailed description for weather_desc column
WMO_TO_DESC = {
    0: "Clear sky",           1: "Mainly clear",
    2: "Partly cloudy",       3: "Overcast",
    45: "Foggy",              48: "Rime fog",
    51: "Light drizzle",      53: "Moderate drizzle",
    55: "Heavy drizzle",      56: "Light freezing drizzle",
    57: "Freezing drizzle",
    61: "Light rain",         63: "Moderate rain",
    65: "Heavy rain",         66: "Light freezing rain",
    67: "Freezing rain",
    71: "Light snow",         73: "Moderate snow",
    75: "Heavy snow",         77: "Snow grains",
    80: "Light showers",      81: "Moderate showers",
    82: "Heavy showers",      85: "Light snow showers",
    86: "Snow showers",
    95: "Thunderstorm",       96: "Thunderstorm with hail",
    99: "Heavy thunderstorm with hail",
}
 
 
# =============================================================
# STEP 1: CALL THE API
# =============================================================
 
print("Calling Open-Meteo API...")
 
params = {
    "latitude": 51.51,
    "longitude": -0.13,
    "start_date": "2009-12-01",
    "end_date": "2011-12-09",
    "daily": ",".join([
        "temperature_2m_mean",
        "temperature_2m_min",
        "temperature_2m_max",
        "relative_humidity_2m_mean",
        "wind_speed_10m_max",
        "rain_sum",
        "weather_code",
    ]),
    "timezone": "Europe/London",
    "wind_speed_unit": "ms",
}
 
response = requests.get(API_URL, params=params)
 
if response.status_code != 200:
    print(f"ERROR: API returned status {response.status_code}")
    print(response.text)
    exit(1)
 
data = response.json()
print(f"Received {len(data['daily']['time'])} days of weather data")
 
 
# =============================================================
# STEP 2: BUILD DATAFRAME
# =============================================================
 
print("Building DataFrame...")
 
daily = data["daily"]
 
df = pd.DataFrame({
    "weather_date":   pd.to_datetime(daily["time"]).date,
    "temp_avg_c":     daily["temperature_2m_mean"],
    "temp_min_c":     daily["temperature_2m_min"],
    "temp_max_c":     daily["temperature_2m_max"],
    "humidity_pct":   daily["relative_humidity_2m_mean"],
    "wind_speed_ms":  daily["wind_speed_10m_max"],
    "rain_mm":        daily["rain_sum"],
    "weather_main":   [WMO_TO_MAIN.get(code, "Unknown") for code in daily["weather_code"]],
    "weather_desc":   [WMO_TO_DESC.get(code, "Unknown") for code in daily["weather_code"]],
})
 
print(f"DataFrame shape: {df.shape}")
 
 
# =============================================================
# STEP 3: LOAD INTO DATABASE
# =============================================================
 
print("Loading into weather_daily table...")
 
df.to_sql(
    name="weather_daily",
    con=engine,
    if_exists="replace",
    index=False,
    method="multi",
)
 
print(f"Loaded {len(df)} rows")
 
 
# =============================================================
# STEP 4: VERIFY
# =============================================================
 
print("\n--- Verification ---")
 
check = pd.read_sql("SELECT COUNT(*) as rows FROM weather_daily", engine)
print(f"Rows in database: {check['rows'][0]}")
 
dates = pd.read_sql(
    "SELECT MIN(weather_date) as first_day, MAX(weather_date) as last_day FROM weather_daily",
    engine,
)
print(f"Date range: {dates['first_day'][0]} to {dates['last_day'][0]}")
 
weather = pd.read_sql(
    "SELECT weather_main, COUNT(*) as days FROM weather_daily GROUP BY weather_main ORDER BY days DESC",
    engine,
)
print("\nWeather distribution:")
print(weather.to_string(index=False))
 
print("\nDone!")