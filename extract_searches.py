#!/usr/bin/env python3
"""
Extract Google Search queries from a screentext.db exported by AWARE ScreenText.

Logic:
  1. Open the SQLite DB
  2. Filter rows where package_name == 'com.android.chrome'
  3. For each row, check if the text starts with '<query> - Google Search'
  4. Extract the query (everything before ' - Google Search')
  5. Deduplicate consecutive identical queries (the same search page
     generates many rows as the accessibility tree updates)
  6. Collect unique ordered queries into searchQueries[]
"""

import sqlite3
import sys
import os

MARKER = " - Google Search"

def extract_search_queries(db_path: str) -> list[str]:
    if not os.path.exists(db_path):
        print(f"Error: {db_path} not found", file=sys.stderr)
        sys.exit(1)

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    cursor.execute(
        "SELECT text FROM screentext "
        "WHERE package_name = 'com.android.chrome' "
        "AND text LIKE ? "
        "ORDER BY timestamp ASC",
        (f"%{MARKER}%",),
    )

    searchQueries: list[str] = []
    seen: set[str] = set()

    for (text,) in cursor:
        idx = text.find(MARKER)
        if idx <= 0:
            continue
        query = text[:idx].strip()
        if query and query not in seen:
            searchQueries.append(query)
            seen.add(query)

    conn.close()
    return searchQueries


if __name__ == "__main__":
    db = sys.argv[1] if len(sys.argv) > 1 else "screentext.db"
    searchQueries = extract_search_queries(db)

    print(f"Found {len(searchQueries)} search queries:\n")
    for i, q in enumerate(searchQueries, 1):
        print(f"  {i}. {q}")
