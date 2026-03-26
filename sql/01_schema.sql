-- ============================================================
-- Schema: retail_weather
-- Tables for analyzing weather impact on retail sales
-- ============================================================

-- Products (unique items from the dataset)
CREATE TABLE IF NOT EXISTS products (
    stock_code  VARCHAR(20) PRIMARY KEY,
    description TEXT,
    category    VARCHAR(100)
);

-- Customers
CREATE TABLE IF NOT EXISTS customers (
    customer_id INTEGER PRIMARY KEY,
    country     VARCHAR(60)
);

-- Sales transactions (one row = one item in an invoice)
CREATE TABLE IF NOT EXISTS sales (
    id           SERIAL PRIMARY KEY,
    invoice_no   VARCHAR(20) NOT NULL,
    stock_code   VARCHAR(20) REFERENCES products(stock_code),
    quantity     INTEGER     NOT NULL,
    invoice_date TIMESTAMP   NOT NULL,
    unit_price   NUMERIC(10,2) NOT NULL,
    customer_id  INTEGER     REFERENCES customers(customer_id),
    country      VARCHAR(60)
);

-- Daily weather for London
CREATE TABLE IF NOT EXISTS weather_daily (
    weather_date    DATE PRIMARY KEY,
    temp_avg_c      NUMERIC(5,2),
    temp_min_c      NUMERIC(5,2),
    temp_max_c      NUMERIC(5,2),
    humidity_pct    SMALLINT,
    wind_speed_ms   NUMERIC(5,2),
    rain_mm         NUMERIC(6,2),
    weather_main    VARCHAR(30),
    weather_desc    VARCHAR(100)
);

-- Indexes for fast JOINs by date
CREATE INDEX IF NOT EXISTS idx_sales_date
    ON sales (DATE(invoice_date));

CREATE INDEX IF NOT EXISTS idx_sales_invoice
    ON sales (invoice_no);