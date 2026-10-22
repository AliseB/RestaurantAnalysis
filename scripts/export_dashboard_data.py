"""Export the analysis tables in zomato.duckdb to CSV files in exports/ for the dashboard."""
import os
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parent.parent
EXPORTS = {
    "regions": "select region, restaurants from region_list order by sort_order",
    "price_tier": "select * from mart_price_tier order by region, price_range",
    "cuisine_price": "select * from mart_cuisine_price order by region, cuisine, price_range",
    "locality": "select * from mart_locality order by region, restaurants desc",
    "votes": "select * from mart_votes order by region, band_order",
    "services": "select * from mart_services order by region, service, price_range, offered",
    "map_points": "select * from mart_map_points order by restaurant_id",
    "map_cities": "select * from mart_map_cities order by restaurants desc",
}


def main() -> None:
    os.chdir(ROOT)
    (ROOT / "exports").mkdir(exist_ok=True)
    con = duckdb.connect(str(ROOT / "zomato.duckdb"), read_only=True)
    for name, sql in EXPORTS.items():
        out = ROOT / "exports" / f"{name}.csv"
        con.execute(f"copy ({sql}) to '{out}' (header, delimiter ',')")
        print(f"  exports/{name}.csv")
    con.close()


if __name__ == "__main__":
    main()
