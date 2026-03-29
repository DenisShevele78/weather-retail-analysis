"""
Load Online Retail II dataset into PostgreSQL.

Steps:
1. Download ZIP from UCI ML Repository
2. Read both Excel sheets
3. Clean data
4. Load into 3 tables: products, customers, sales
"""

import os
import zipfile
import requests
import pandas as pd
from sqlalchemy import create_engine, text

# --- SETTINGS ---

# URL of the dataset (UCI ML Repository)
DATA_URL = "https://archive.ics.uci.edu/static/public/502/online+retail+ii.zip"
ZIP_PATH = "data/online_retail_ii.zip"

# PostgreSQL connection
DB_HOST = "localhost"
DB_PORT = 5433
DB_NAME = "retail_weather"
DB_USER = "analyst"
DB_PASS = "analyst_pass"

# SQLAlchemy connection string (строка подключения к базе данных)
DB_URL = f"postgresql://{DB_USER}:{DB_PASS}@{DB_HOST}:{DB_PORT}/{DB_NAME}"


# --- STEP 1: DOWNLOAD ---

def download_data():
    """Download ZIP file if it doesn't already exist."""
    if os.path.exists(ZIP_PATH):
        print(f"[OK] File already exists: {ZIP_PATH}")
        return

    # Create data/ folder if it doesn't exist
    os.makedirs("data", exist_ok=True)

    print(f"[...] Downloading dataset from UCI...")
    response = requests.get(DATA_URL, timeout=120)
    response.raise_for_status()  # raise error if download fails

    with open(ZIP_PATH, "wb") as f:
        f.write(response.content)

    print(f"[OK] Downloaded: {ZIP_PATH} ({len(response.content) / 1024 / 1024:.1f} MB)")


# --- STEP 2: READ EXCEL ---

def read_excel_from_zip():
    """Read both sheets from the Excel file inside the ZIP."""
    print("[...] Reading Excel file from ZIP (this may take 1-2 minutes)...")

    with zipfile.ZipFile(ZIP_PATH, "r") as z:
        # Find the Excel file inside ZIP
        excel_files = [f for f in z.namelist() if f.endswith(".xlsx")]
        if not excel_files:
            raise FileNotFoundError("No .xlsx file found inside ZIP")

        excel_name = excel_files[0]
        print(f"[OK] Found Excel file: {excel_name}")

        with z.open(excel_name) as excel_file:
            # Read both sheets (два листа Excel)
            df1 = pd.read_excel(excel_file, sheet_name="Year 2009-2010", engine="openpyxl")
            # Need to re-open because file pointer moved
            excel_file.seek(0)
            df2 = pd.read_excel(excel_file, sheet_name="Year 2010-2011", engine="openpyxl")

    # Combine both sheets into one DataFrame
    df = pd.concat([df1, df2], ignore_index=True)
    print(f"[OK] Total rows from Excel: {len(df):,}")

    return df


# --- STEP 3: CLEAN DATA ---

def clean_data(df):
    """Clean the raw data: remove bad rows, fix types."""
    print("[...] Cleaning data...")

    rows_before = len(df)

    # Standardize column names: lowercase, replace spaces with underscores
    # "Invoice" → "invoice", "Customer ID" → "customer_id"
    df.columns = df.columns.str.strip().str.lower().str.replace(" ", "_")

    # Remove rows where customer_id is missing (нет ID покупателя)
    df = df.dropna(subset=["customer_id"])

    # Remove cancelled orders — invoice starts with "C" (отмены заказов)
    df = df[~df["invoice"].astype(str).str.startswith("C")]

    # Remove rows with negative or zero price
    df = df[df["price"] > 0]

    # Remove rows with zero quantity
    df = df[df["quantity"] > 0]

    # Fix data types (исправляем типы данных)
    df["customer_id"] = df["customer_id"].astype(int)
    df["invoice"] = df["invoice"].astype(str).str.strip()
    df["stockcode"] = df["stockcode"].astype(str).str.strip()
    df["description"] = df["description"].astype(str).str.strip()

    rows_after = len(df)
    removed = rows_before - rows_after
    print(f"[OK] Removed {removed:,} bad rows. Clean rows: {rows_after:,}")

    return df


# --- STEP 4: LOAD INTO DATABASE ---

def load_to_database(df):
    """Split clean data into 3 tables and load into PostgreSQL."""

    engine = create_engine(DB_URL)

    # --- PRODUCTS table ---
    print("[...] Loading products...")
    products = (
        df[["stockcode", "description"]]
        .drop_duplicates(subset=["stockcode"])
        .rename(columns={"stockcode": "stock_code"})
    )
    # category will be filled later (Step 6)
    products["category"] = None

    # Clear table before loading (очищаем таблицу перед загрузкой)
    with engine.begin() as conn:
        conn.execute(text("TRUNCATE TABLE sales, products, customers CASCADE"))

    products.to_sql("products", engine, if_exists="append", index=False)
    print(f"[OK] Products loaded: {len(products):,}")

    # --- CUSTOMERS table ---
    print("[...] Loading customers...")
    customers = (
        df[["customer_id", "country"]]
        .drop_duplicates(subset=["customer_id"])
    )
    customers.to_sql("customers", engine, if_exists="append", index=False)
    print(f"[OK] Customers loaded: {len(customers):,}")

    # --- SALES table ---
    print("[...] Loading sales (this may take a minute)...")
    sales = df[["invoice", "stockcode", "quantity", "invoicedate", "price", "customer_id", "country"]].copy()
    sales = sales.rename(columns={
        "invoice": "invoice_no",
        "stockcode": "stock_code",
        "invoicedate": "invoice_date",
        "price": "unit_price",
    })

    # Load in chunks of 10,000 rows (загружаем частями по 10,000 строк)
    # This prevents memory issues with large datasets
    CHUNK_SIZE = 10_000
    total = len(sales)
    for start in range(0, total, CHUNK_SIZE):
        end = min(start + CHUNK_SIZE, total)
        chunk = sales.iloc[start:end]
        chunk.to_sql("sales", engine, if_exists="append", index=False)

        # Show progress (показываем прогресс)
        pct = end / total * 100
        print(f"  ... {end:,} / {total:,} rows ({pct:.0f}%)")

    print(f"[OK] Sales loaded: {total:,}")

    engine.dispose()


# --- STEP 5: VERIFY ---

def verify():
    """Check row counts in the database."""
    engine = create_engine(DB_URL)

    print("\n--- VERIFICATION (проверка) ---")
    with engine.connect() as conn:
        for table in ["products", "customers", "sales"]:
            result = conn.execute(text(f"SELECT COUNT(*) FROM {table}"))
            count = result.scalar()
            print(f"  {table}: {count:,} rows")

    engine.dispose()


# --- MAIN ---

if __name__ == "__main__":
    print("=" * 50)
    print("Loading Online Retail II into PostgreSQL")
    print("=" * 50)

    download_data()
    df = read_excel_from_zip()
    df = clean_data(df)
    load_to_database(df)
    verify()

    print("\n[DONE] All data loaded successfully!")
