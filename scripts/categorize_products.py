"""
Categorize Products by keyword matching.

Step 6 of Weather × Retail Sales project.
Assigns a category to each product in the products table
based on keyword matching against product descriptions.

Categories: Home Decor, Kitchen, Candles & Lighting, Bags & Wrap,
Jewelry, Stationery, Textiles, Gifts, Toys & Fun, Heart & Love,
Christmas, Garden, Other.
"""

import pandas as pd
from sqlalchemy import create_engine, text


# =============================================================
# SETTINGS — change these to match your environment
# =============================================================

DB_URL = "postgresql://user:password@localhost:5433/retail_weather"
engine = create_engine(DB_URL)


# =============================================================
# CATEGORY KEYWORDS
# =============================================================

CATEGORIES = {
    "Candles & Lighting": ["CANDLE", "T-LIGHT", "LANTERN", "LAMP", "LIGHT", "TORCH", "TEALIGHT"],
    "Home Decor":         ["DECORATION", "HANGING", "WALL", "SIGN", "FRAME", "MIRROR",
                           "DOORMAT", "DOOR MAT", "DOORSTOP", "ORNAMENT", "WREATH",
                           "DRAWER KNOB", "HOOK", "CLOCK", "TRINKET", "CHEST",
                           "GARLAND", "DOOR HANGER", "CABINET", "SOAP", "BIRD",
                           "DUCK", "BUNTING", "CERAMIC", "PORCELAIN"],
    "Kitchen":            ["MUG", "TRAY", "PLATE", "DISH", "BOWL", "EGG", "SPOON", "LADLE",
                           "JAR", "JUG", "COASTER", "CAKE", "BAKING", "FRYING PAN",
                           "GLASS", "GOBLET", "MAGNET", "TEAPOT", "CUP", "MATCHES",
                           "NAPKIN", "BOTTLE OPENER"],
    "Bags & Wrap":        ["BAG", "WRAP", "TISSUE", "PURSE", "CASE", "TAG", "LUGGAGE"],
    "Jewelry":            ["NECKLAC", "BRACELET", "EARRING", "RING", "JEWEL", "BEAD",
                           "BROOCH", "HAIRCLIP", "HAIR COMB", "HAIR", "CLIP"],
    "Stationery":         ["CARD", "PAPER", "PENCIL", "PEN", "NOTEBOOK", "SKETCHBOOK",
                           "LETTER", "STICKER", "WRITING", "CHALK", "STAMP", "IRON ON",
                           "ALBUM", "DIARY", "INVITE"],
    "Christmas":          ["CHRISTMAS", "XMAS", "ADVENT", "SANTA", "SNOWMAN", "REINDEER"],
    "Textiles":           ["CUSHION", "COVER", "TOWEL", "APRON", "TEA TOWEL",
                           "HOT WATER BOTTLE", "HOTTIE", "GLOVE", "UMBRELLA",
                           "SEWING", "CROCHET", "KNIT"],
    "Toys & Fun":         ["TOY", "GAME", "PUZZLE", "CRAYON", "DOLL", "PUPPET",
                           "BINGO", "GLOBE", "JIGSAW", "FIGURE", "BUILDING BLOCK",
                           "MOBILE", "SNAKES", "MONKEY", "DINOSAUR", "ANIMAL"],
    "Gifts":              ["BOX", "MONEY", "GIFT", "PRESENT", "SET", "TIN"],
    "Garden":             ["POTTING", "GARDEN", "GROW", "SEED", "PLANT", "FLOWER POT"],
    "Heart & Love":       ["HEART", "LOVE", "DOVE"],
}


# =============================================================
# CATEGORIZE FUNCTION
# =============================================================

def categorize(desc):
    """Assign a category to a product based on its description."""
    if desc is None:
        return "Other"
    for cat, keywords in CATEGORIES.items():
        if any(kw in desc.upper() for kw in keywords):
            return cat
    return "Other"


# =============================================================
# STEP 1: READ PRODUCTS
# =============================================================

print("Reading products from database...")
products = pd.read_sql("SELECT stock_code, description FROM products", engine)
print(f"Total products: {len(products)}")


# =============================================================
# STEP 2: ASSIGN CATEGORIES
# =============================================================

print("Assigning categories...")
products["category"] = products["description"].apply(categorize)

matched = len(products[products["category"] != "Other"])
print(f"Matched: {matched} / {len(products)}")
print(f"Unmatched (Other): {len(products) - matched}")


# =============================================================
# STEP 3: UPDATE DATABASE
# =============================================================

print("Updating database...")

with engine.connect() as conn:
    for _, row in products.iterrows():
        conn.execute(
            text("UPDATE products SET category = :cat WHERE stock_code = :code"),
            {"cat": row["category"], "code": row["stock_code"]}
        )
    conn.commit()

print("Database updated!")


# =============================================================
# STEP 4: VERIFY
# =============================================================

print("\n--- Verification ---")

check = pd.read_sql(
    "SELECT category, COUNT(*) as products FROM products GROUP BY category ORDER BY products DESC",
    engine,
)
print(check.to_string(index=False))

print("\nDone!")