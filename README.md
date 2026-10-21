# RestaurantAnalysis

Exploratory analysis of the [Zomato restaurant dataset](https://www.kaggle.com/datasets/srisyra02/zomato-market-analysis) (9,551 restaurants, 15 countries) using SQL in [DuckDB](https://duckdb.org).

## Project layout

```
data/raw/zomato.csv            # original Kaggle CSV (unchanged)
data/seed/country_codes.csv    # country code -> country name lookup
sql/01_load_raw.sql            # loads the CSVs into raw tables
sql/02_staging.sql             # builds cleaned, analysis-ready tables
sql/eda_01_overview.sql        # starter EDA queries
scripts/build_db.py            # runs the load + staging SQL -> zomato.duckdb
```

## Setup

```bash
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python scripts/build_db.py          # creates zomato.duckdb (git-ignored)
```

## Querying

```bash
duckdb zomato.duckdb                          # interactive SQL shell
duckdb zomato.duckdb < sql/eda_01_overview.sql
duckdb -ui zomato.duckdb                      # browser-based notebook UI
```

The DuckDB file can also be opened in DBeaver, DataGrip or VS Code.

## Tables

| Table | Grain | Notes |
|---|---|---|
| `raw_restaurants` | 1 row per restaurant | CSV as-is, original column names |
| `restaurants` | 1 row per restaurant | snake_case columns, `country` joined in, `rating` is NULL when not rated |
| `restaurant_cuisines` | 1 row per restaurant x cuisine | `cuisines` list split apart |
| `country_codes` | 1 row per country | lookup |

## Data quirks to know

- **Not rated:** 2,148 restaurants have rating `0` / "Not rated"; these are NULL in `restaurants.rating`.
- **Currency:** `avg_cost_for_two` is in local currency, so don't compare it across countries without converting. The Philippines is labelled "Botswana Pula(P)" in the source; it is really pesos.
- **Encoding:** some non-English names are garbled in the source file (e.g. `Bras�_lia`, `��stanbul`).
- **India-heavy:** 91% of rows are in India (mostly New Delhi, Gurgaon and Noida).
- **Coordinates:** 499 rows have a 0 latitude or longitude.
- 9 rows have no cuisines.
