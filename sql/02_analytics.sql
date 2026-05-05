-- =============================================================================
-- 02_analytics.sql — Step 7: SQL Analytics
-- =============================================================================
--
-- Project: Weather × Retail Sales Analysis
-- Purpose: Explore the relationship between weather and daily retail sales,
--          and identify which product categories may be weather-sensitive.
--
-- IMPORTANT NOTE ON METHODOLOGY:
--   These queries are EXPLORATORY only. They reveal patterns and group
--   averages, but do NOT prove that weather CAUSES the observed differences.
--   The data has known confounds — most importantly, weather is correlated
--   with season (e.g., "Cold" days = winter = Christmas season).
--
--   Honest conclusions about weather effects require:
--     - Controlling for season, day-of-week, holidays (Step 8: Python)
--     - Statistical significance tests (t-test, ANOVA)
--     - Sufficient sample sizes per group
--
-- Tables involved:
--   sales         805,549 rows  Dec 2009 – Dec 2011
--   products        4,631 rows  13 categories assigned
--   customers       5,878 rows  mostly UK
--   weather_daily     739 rows  daily London weather
-- =============================================================================


-- =============================================================================
-- Q0. Data exploration — basic counts and date coverage
-- =============================================================================

-- Number of unique sales days (compare with 739 weather days)
SELECT COUNT(DISTINCT DATE(invoice_date)) AS days_with_sales
FROM sales;
-- Result: 604 (so 135 days have no sales — see Q0b for why)


-- Q0b. Day-of-week distribution — when is the shop open?
SELECT
    EXTRACT(DOW FROM invoice_date) AS day_of_week_number,
    TO_CHAR(invoice_date, 'Day') AS day_name,
    COUNT(DISTINCT DATE(invoice_date)) AS days_with_sales,
    COUNT(*) AS total_transactions
FROM sales
GROUP BY day_of_week_number, day_name
ORDER BY day_of_week_number;
-- Finding: Shop is essentially closed on Saturdays (only 1 Saturday with sales).
-- All other weekdays have ~94–104 days. Total: 604 days. This explains the gap.


-- =============================================================================
-- Q1. Daily sales metrics joined with weather (the core JOIN)
-- =============================================================================
-- Foundation for all subsequent analyses. Combines daily-aggregated sales
-- with daily weather. INNER JOIN gives 604 rows (only days with both data).

WITH daily_sales AS (
    SELECT
        DATE(invoice_date) AS sale_date,
        SUM(quantity * unit_price) AS revenue,
        COUNT(DISTINCT invoice_no) AS transactions,
        SUM(quantity) AS items_sold,
        COUNT(DISTINCT customer_id) AS unique_customers
    FROM sales
    GROUP BY DATE(invoice_date)
)
SELECT
    ds.sale_date,
    ds.revenue,
    ds.transactions,
    ds.items_sold,
    ds.unique_customers,
    w.temp_avg_c,
    w.rain_mm,
    w.weather_main,
    w.weather_desc
FROM daily_sales ds
INNER JOIN weather_daily w ON ds.sale_date = w.weather_date
ORDER BY ds.sale_date;


-- =============================================================================
-- Q2. Sales by weather condition (Clear, Cloudy, Drizzle, Rain, Snow)
-- =============================================================================
-- Compares average daily metrics across weather categories.
-- AOV (Average Order Value) is included to separate "fewer customers"
-- from "smaller baskets per visit".

WITH daily_sales AS (
    SELECT
        DATE(invoice_date) AS sale_date,
        SUM(quantity * unit_price) AS revenue,
        COUNT(DISTINCT invoice_no) AS transactions,
        SUM(quantity) AS items_sold,
        COUNT(DISTINCT customer_id) AS unique_customers
    FROM sales
    GROUP BY DATE(invoice_date)
)
SELECT
    w.weather_main,
    COUNT(*) AS days_count,
    ROUND(AVG(ds.revenue)::numeric, 2) AS avg_revenue,
    ROUND(AVG(ds.transactions)::numeric, 1) AS avg_transactions,
    ROUND(AVG(ds.items_sold)::numeric, 0) AS avg_items_sold,
    ROUND(AVG(ds.unique_customers)::numeric, 1) AS avg_customers,
    ROUND((SUM(ds.revenue) / SUM(ds.transactions))::numeric, 2) AS avg_order_value
FROM daily_sales ds
INNER JOIN weather_daily w ON ds.sale_date = w.weather_date
GROUP BY w.weather_main
ORDER BY avg_revenue DESC;
-- Finding: Range from £27,257 (Snow) to £32,826 (Clear) — about 17% spread.
-- Snow has lowest revenue but HIGHEST AOV (£532): fewer customers, bigger orders.
-- WARNING: Sample sizes very unequal (Cloudy=288 days, Clear=17 days).


-- =============================================================================
-- Q3. London temperature distribution — for designing temperature buckets
-- =============================================================================

SELECT
    MIN(temp_avg_c) AS min_temp,
    MAX(temp_avg_c) AS max_temp,
    ROUND(AVG(temp_avg_c)::numeric, 1) AS avg_temp,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY temp_avg_c) AS p25,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY temp_avg_c) AS median,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY temp_avg_c) AS p75
FROM weather_daily;
-- Result: min=-6.5, max=22.8, avg=10.1, P25=5.5, median=10.9, P75=14.85
-- London weather is mild and symmetric — usable for percentile-based buckets.


-- =============================================================================
-- Q4. Sales by temperature range (using percentile-based buckets)
-- =============================================================================
-- Each bucket holds ~25% of weather days for fair comparison.

WITH daily_sales AS (
    SELECT
        DATE(invoice_date) AS sale_date,
        SUM(quantity * unit_price) AS revenue,
        COUNT(DISTINCT invoice_no) AS transactions,
        SUM(quantity) AS items_sold,
        COUNT(DISTINCT customer_id) AS unique_customers
    FROM sales
    GROUP BY DATE(invoice_date)
),
sales_with_weather AS (
    SELECT
        ds.*,
        w.temp_avg_c,
        CASE
            WHEN w.temp_avg_c < 5.5   THEN '1. Cold (<5.5°C)'
            WHEN w.temp_avg_c < 10.9  THEN '2. Cool (5.5-10.9°C)'
            WHEN w.temp_avg_c < 14.85 THEN '3. Mild (10.9-14.85°C)'
            ELSE                            '4. Warm (>=14.85°C)'
        END AS temp_range
    FROM daily_sales ds
    INNER JOIN weather_daily w ON ds.sale_date = w.weather_date
)
SELECT
    temp_range,
    COUNT(*) AS days_count,
    ROUND(AVG(temp_avg_c)::numeric, 1) AS avg_temp_c,
    ROUND(AVG(revenue)::numeric, 2) AS avg_revenue,
    ROUND(AVG(transactions)::numeric, 1) AS avg_transactions,
    ROUND(AVG(items_sold)::numeric, 0) AS avg_items_sold,
    ROUND(AVG(unique_customers)::numeric, 1) AS avg_customers,
    ROUND((SUM(revenue) / SUM(transactions))::numeric, 2) AS avg_order_value
FROM sales_with_weather
GROUP BY temp_range
ORDER BY temp_range;
-- Finding: Mild = highest revenue (£30,795), Warm = lowest (£26,563).
-- Spread ~15%. BUT this is heavily confounded with season — see Q5.


-- =============================================================================
-- Q5. Average temperature by month — confirms the season confound
-- =============================================================================
-- Run AFTER Q4 to see why temperature buckets correlate with seasons.

SELECT
    EXTRACT(MONTH FROM weather_date) AS month_num,
    TO_CHAR(weather_date, 'Month') AS month_name,
    ROUND(AVG(temp_avg_c)::numeric, 1) AS avg_temp,
    COUNT(*) AS days
FROM weather_daily
GROUP BY month_num, month_name
ORDER BY month_num;
-- Finding: Cold months (Dec/Jan/Feb) = winter & Christmas season.
-- Warm months (Jun/Jul/Aug) = summer holidays.
-- => Temperature buckets in Q4 strongly overlap with seasons.
-- => Apparent "weather effects" cannot be separated from "season effects" in SQL.


-- =============================================================================
-- Q6. Sales by category × weather (pivot table format)
-- =============================================================================
-- Long format would be 65 rows (13 categories × 5 weather types) — hard to read.
-- We pivot to wide format: one row per category, one column per weather.
-- revenue_spread_pct shows how much revenue varies across weather buckets,
-- but does NOT prove weather is the cause. Season, day-of-week, sample size
-- effects are all mixed in.

WITH daily_category_sales AS (
    SELECT
        DATE(s.invoice_date) AS sale_date,
        p.category,
        SUM(s.quantity * s.unit_price) AS revenue
    FROM sales s
    INNER JOIN products p ON s.stock_code = p.stock_code
    GROUP BY DATE(s.invoice_date), p.category
),
category_weather AS (
    SELECT
        dcs.category,
        w.weather_main,
        AVG(dcs.revenue) AS avg_revenue
    FROM daily_category_sales dcs
    INNER JOIN weather_daily w ON dcs.sale_date = w.weather_date
    GROUP BY dcs.category, w.weather_main
)
SELECT
    category,
    ROUND(SUM(CASE WHEN weather_main = 'Clear'   THEN avg_revenue ELSE 0 END)::numeric, 0) AS clear,
    ROUND(SUM(CASE WHEN weather_main = 'Cloudy'  THEN avg_revenue ELSE 0 END)::numeric, 0) AS cloudy,
    ROUND(SUM(CASE WHEN weather_main = 'Drizzle' THEN avg_revenue ELSE 0 END)::numeric, 0) AS drizzle,
    ROUND(SUM(CASE WHEN weather_main = 'Rain'    THEN avg_revenue ELSE 0 END)::numeric, 0) AS rain,
    ROUND(SUM(CASE WHEN weather_main = 'Snow'    THEN avg_revenue ELSE 0 END)::numeric, 0) AS snow,
    ROUND(AVG(avg_revenue)::numeric, 0) AS category_avg,
    ROUND(((MAX(avg_revenue) - MIN(avg_revenue)) / AVG(avg_revenue) * 100)::numeric, 1) AS revenue_spread_pct
FROM category_weather
GROUP BY category
ORDER BY revenue_spread_pct DESC;
-- Finding: Largest spreads — Christmas (76%), Textiles (65%), Garden (44%).
-- Smallest spread — Kitchen (8%). Suggests weather-stable vs weather-variable
-- categories, but with the season-confound caveat above.


-- =============================================================================
-- Q7. Rain distribution — for designing rain buckets
-- =============================================================================

SELECT
    COUNT(*) FILTER (WHERE rain_mm = 0)                          AS no_rain_days,
    COUNT(*) FILTER (WHERE rain_mm > 0  AND rain_mm < 1)         AS trace_rain_days,
    COUNT(*) FILTER (WHERE rain_mm >= 1 AND rain_mm < 5)         AS light_rain_days,
    COUNT(*) FILTER (WHERE rain_mm >= 5 AND rain_mm < 10)        AS moderate_rain_days,
    COUNT(*) FILTER (WHERE rain_mm >= 10)                        AS heavy_rain_days,
    ROUND(MAX(rain_mm)::numeric, 1) AS max_rain
FROM weather_daily;


-- =============================================================================
-- Q8. Sales by rain bucket
-- =============================================================================
-- Bucket boundaries chosen by real-world thresholds, not percentiles,
-- because most days have zero rain (skewed distribution).

WITH daily_sales AS (
    SELECT
        DATE(invoice_date) AS sale_date,
        SUM(quantity * unit_price) AS revenue,
        COUNT(DISTINCT invoice_no) AS transactions,
        SUM(quantity) AS items_sold,
        COUNT(DISTINCT customer_id) AS unique_customers
    FROM sales
    GROUP BY DATE(invoice_date)
),
sales_with_rain AS (
    SELECT
        ds.*,
        w.rain_mm,
        CASE
            WHEN w.rain_mm = 0   THEN '1. No rain (0 mm)'
            WHEN w.rain_mm < 1   THEN '2. Trace (0-1 mm)'
            WHEN w.rain_mm < 5   THEN '3. Light (1-5 mm)'
            WHEN w.rain_mm < 10  THEN '4. Moderate (5-10 mm)'
            ELSE                      '5. Heavy (10+ mm)'
        END AS rain_bucket
    FROM daily_sales ds
    INNER JOIN weather_daily w ON ds.sale_date = w.weather_date
)
SELECT
    rain_bucket,
    COUNT(*) AS days_count,
    ROUND(AVG(rain_mm)::numeric, 2) AS avg_rain_mm,
    ROUND(AVG(revenue)::numeric, 2) AS avg_revenue,
    ROUND(AVG(transactions)::numeric, 1) AS avg_transactions,
    ROUND(AVG(items_sold)::numeric, 0) AS avg_items_sold,
    ROUND(AVG(unique_customers)::numeric, 1) AS avg_customers,
    ROUND((SUM(revenue) / SUM(transactions))::numeric, 2) AS avg_order_value
FROM sales_with_rain
GROUP BY rain_bucket
ORDER BY rain_bucket;
-- Finding: (fill in after running)


-- =============================================================================
-- STEP 7 SUMMARY — WHAT WE LEARNED
-- =============================================================================
--
-- 1. DATA SHAPE
--    - 604 days of sales, 739 days of weather → 135-day gap (mostly Saturdays)
--    - Average basket ~£500, ~400 items/transaction → looks like a B2B/wholesale
--      gift retailer (UCI says "online retail, gift-ware"; many wholesalers)
--
-- 2. WEATHER CONDITION (Q2)
--    - Clear days have highest avg revenue (£32,826), Snow lowest (£27,257)
--    - 17% spread between best and worst weather
--    - Snow has FEWEST customers but BIGGEST orders (AOV £532) — interesting!
--    - Sample sizes very unequal — Clear has only 17 days
--
-- 3. TEMPERATURE (Q4) — CONFOUNDED WITH SEASON (Q5)
--    - Apparent ranking: Mild > Cold > Cool > Warm
--    - But "Cold" = winter (Dec/Jan/Feb, includes Christmas)
--      "Warm" = summer (Jun/Jul/Aug, holiday season)
--    - Cannot conclude weather causes the differences in SQL alone
--
-- 4. CATEGORY × WEATHER (Q6)
--    - Largest revenue spread: Christmas (76%), Textiles (65%), Garden (44%)
--    - Smallest revenue spread: Kitchen (8%) — most stable category
--    - Promising candidates for Step 8: Textiles peaks on snow days,
--      Kitchen is weather-neutral
--
-- 5. RAIN (Q8) — to be filled in after running
--
-- =============================================================================
-- WHAT THIS ANALYSIS CANNOT TELL US (limits of SQL alone)
-- =============================================================================
--
-- - We CANNOT prove causation. Spread ≠ weather effect.
-- - We CANNOT separate weather from season, day-of-week, holidays.
-- - We CANNOT test statistical significance (is the spread real or random?).
-- - We CANNOT detect lag effects (e.g., bad weather today → bigger order
--   tomorrow when stock runs low).
-- - We CANNOT control for sample size differences across weather buckets.
--
-- => All these require Step 8 (Python + scipy + statsmodels).
--
-- =============================================================================
-- NEXT STEPS
-- =============================================================================
--
-- Step 8 (Python in Jupyter):
--   - Load this data into pandas DataFrames
--   - Visualize with matplotlib/seaborn (heatmaps, time series, scatter plots)
--   - Calculate Pearson and Spearman correlations
--   - Run t-tests / ANOVA for weather group differences
--   - Add MONTH and DAY-OF-WEEK as control variables
--   - Test lag effects (revenue today vs weather N days ago)
--   - Per-category significance tests
--
-- =============================================================================
