"""Build zomato.duckdb from the raw CSV by running the SQL files in order."""
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parent.parent
SQL_FILES = ["01_load_raw.sql", "02_staging.sql", "03_marts.sql"]


def main() -> None:
    con = duckdb.connect(str(ROOT / "zomato.duckdb"))
    for name in SQL_FILES:
        print(f"Running {name}")
        con.execute((ROOT / "sql" / name).read_text())
    for (table,) in con.execute("select table_name from information_schema.tables order by table_name").fetchall():
        (count,) = con.execute(f"select count(*) from {table}").fetchone()
        print(f"  {table}: {count:,} rows")
    con.close()


if __name__ == "__main__":
    import os

    os.chdir(ROOT)
    main()
