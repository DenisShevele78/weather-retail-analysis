# How Weather Affects Retail Sales

## Project Goal

Determine if there is a statistically significant relationship between weather conditions (temperature, precipitation, wind) and retail sales volume. Identify which product categories are most weather-dependent and discover temperature thresholds that influence buying behavior.

## Business Question

**Does weather impact what people buy?**
- Which product categories are most affected by weather?
- Does temperature have a threshold effect (e.g., sales drop below 5°C)?
- Do rainy days boost sales of umbrellas and home products?

## Data Sources

| Source | Data | Period | Size |
|--------|------|--------|------|
| **Online Retail II** (UCI ML Repository) | Transaction history, product descriptions, customer purchases | 2009–2011 | ~1M transactions |
| **Open-Meteo Archive API** | Daily temperature, precipitation, wind speed | 2009–2011 | 1,095 days |
| **Location** | London, United Kingdom | — | — |

## Tech Stack

- **Database:** PostgreSQL (Docker)
- **Data Processing:** Python (pandas, numpy)
- **Statistical Analysis:** scipy, statsmodels
- **Visualization:** matplotlib, seaborn
- **BI Dashboard:** Metabase (or Superset)
- **Version Control:** Git, GitHub

## Project Structure
```
weather-retail-analysis/
├── README.md                 # This file
├── docker-compose.yml        # PostgreSQL + Metabase setup
├── requirements.txt          # Python dependencies
├── .gitignore               # Git ignore rules
│
├── sql/
│   ├── 01_schema.sql        # Create tables: sales, products, weather_daily
│   └── 02_analytics.sql     # Queries: correlations, aggregations
│
├── scripts/
│   ├── load_sales.py        # Download and load Online Retail II data
│   ├── load_weather.py      # Fetch weather data from API
│   └── categorize_products.py # Assign product categories
│
├── notebooks/
│   └── 01_eda_and_correlation.ipynb  # EDA, statistics, visualizations
│
├── data/
│   └── (CSV files downloaded during execution)
│
└── dashboards/
    └── (Metabase screenshots or dashboard exports)
```

## How to Reproduce This Project

### Prerequisites

- Docker & Docker Compose installed
- Python 3.9+
- Git

### Step 1: Clone the Repository
```bash
git clone https://github.com/YOUR-USERNAME/weather-retail-analysis.git
cd weather-retail-analysis
```

### Step 2: Start PostgreSQL and Metabase
```bash
docker-compose up -d
```

This starts:
- PostgreSQL on `localhost:5432`
- Metabase on `localhost:3000`

### Step 3: Set Up Python Environment
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
```

### Step 4: Load Data
```bash
python scripts/load_sales.py      # ~2 minutes
python scripts/load_weather.py    # ~1 minute
python scripts/categorize_products.py
```

### Step 5: Run Analysis

Open and run the Jupyter notebook:
```bash
jupyter notebook notebooks/01_eda_and_correlation.ipynb
```

### Step 6: View Dashboard

Open browser → `http://localhost:3000` → Log in to Metabase and explore dashboards.

## Key Findings

*To be completed after analysis*

- [ ] Correlation between temperature and sales volume
- [ ] Which product categories are most weather-sensitive
- [ ] Temperature thresholds identified
- [ ] Statistical significance (p-value)

## Technologies & Decisions

**Why PostgreSQL?** Demonstrates SQL skills and real-world data engineering (normalization, queries, optimization).

**Why Open-Meteo instead of OpenWeatherMap?** Free historical data without API keys or rate limits.

**Why Metabase?** Open-source, easy setup, good for portfolio projects (alternative: Superset, Power BI).

## Project Phases

| Phase | Task | Duration | Status |
|-------|------|----------|--------|
| 1 | Infrastructure & PostgreSQL setup | 1–2 days | ✅ Done |
| 2 | Load and normalize sales + weather data | 1–2 days | ⏳ In Progress |
| 3 | SQL analytics & correlation analysis | 2–3 days | ⏳ Pending |
| 4 | Python statistics & visualization | 3–4 days | ⏳ Pending |
| 5 | Metabase dashboard creation | 1–2 days | ⏳ Pending |
| 6 | Final documentation & cleanup | 1 day | ⏳ Pending |

## How to Contribute

This is a personal portfolio project. For feedback or suggestions, please open an issue or contact me.

## License

MIT License — see LICENSE file for details.

---

**Author:** Denis Shevelev  
**Last Updated:** March 2026