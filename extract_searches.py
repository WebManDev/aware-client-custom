#!/usr/bin/env python3
"""
Extract Google Search queries from a screentext*.db exported by AWARE ScreenText.

ScreenText logs many snapshots of the same Google results page. This script:

1. Reads Chrome rows whose text contains " - Google Search" (results-page marker).
2. Parses the real query from the embedded Google URL (`q`), not from visible UI text.
3. Treats Google's `ved=` token as a page signature: consecutive identical signatures
   are collapsed to one event.
4. Suppresses a signature that reappears after a moderate delay (tunable min/max ms),
   which often corresponds to Chrome briefly flashing an older results page.

Duplicate queries in separate searches are still counted when they correspond to
new signatures / outside the revisit-suppression window.
"""

import re
import sqlite3
import argparse
from urllib.parse import unquote

MARKER = " - Google Search"

# Signature revisit heuristic:
# When users type quickly, Chrome can briefly re-render an older Google
# results page. ScreenText then captures it as extra events.
#
# Empirically for your data:
# - Repeated signatures within a short interval are usually "real recapture"
#   of the same page -> collapse by consecutive signature.
# - Repeated signatures that reappear after a moderate delay are usually
#   flashback noise (old results page just before the next navigation).
# - Repeated signatures after a long delay look like a deliberate repeat.
#
# We implement this as: if the same signature is seen again after >= MIN_MS
# and < MAX_MS, suppress it.
REVISIT_SUPPRESS_MIN_MS = 8_000
REVISIT_SUPPRESS_MAX_MS = 60_000
FLASHBACK_NEXT_WINDOW_MS = 2_500
QUERY_FLASHBACK_MIN_GAP_MS = 90_000
QUERY_FLASHBACK_MAX_GAP_MS = 900_000
QUERY_FLASHBACK_NEXT_WINDOW_MS = 30_000

# Extract the actual `ved` token. In AWARE ScreenText blobs the `ved=` parameter
# is often immediately followed by "***Rect(...", and sometimes there is no '&'
# delimiter. We stop on '&', '*' or whitespace.
VED_RE = re.compile(r"ved=([^&*\s]+)")

Q_URL_RE = re.compile(r"search%3Fq%3D(.+?)%26")
Q_FALLBACK_RE = re.compile(r"search\\?q=([^&]+)")


def extract_query_from_google_url(chrome_text: str) -> str:
    """
    Extract the user's query from Chrome's Google results URL fragment stored
    in the ScreenText blob.

    This is much more reliable than taking substring-before-marker, because
    the ScreenText accessibility tree often contains extra UI text.
    """
    m = Q_URL_RE.search(chrome_text)
    if m:
        # Query param is often nested-encoded: decode twice.
        raw = m.group(1)
        q = unquote(unquote(raw)).replace('+', ' ').strip()
        return q

    m = Q_FALLBACK_RE.search(chrome_text)
    if m:
        raw = m.group(1)
        q = unquote(unquote(raw)).replace('+', ' ').strip()
        return q

    return ""


def choose_latest_screentext_table_name(conn: sqlite3.Connection) -> str:
    cursor = conn.cursor()
    cursor.execute(
        "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE 'screentext%'"
    )
    rows = cursor.fetchall()
    max_idx = 1
    found_any = False
    for (name,) in rows:
        if name == "screentext":
            found_any = True
            max_idx = max(max_idx, 1)
            continue
        m = re.match(r"^screentext(\d+)$", name)
        if m:
            found_any = True
            max_idx = max(max_idx, int(m.group(1)))

    if not found_any:
        return "screentext"
    return "screentext" if max_idx == 1 else ("screentext" + str(max_idx))


def extract_chrome_events(
    db_path: str,
    table_name: str,
    revisit_suppress_min_ms: int = REVISIT_SUPPRESS_MIN_MS,
    revisit_suppress_max_ms: int = REVISIT_SUPPRESS_MAX_MS,
) -> list[tuple[int, str, str]]:
    """
    Extract Chrome events as a sequence of (timestamp_ms, query, signature).

    We compress repeated Accessibility snapshots of the *same* page by only
    keeping events when the signature changes.
    """
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute(
        "SELECT timestamp, text FROM " + table_name + " "
        "WHERE package_name = 'com.android.chrome' "
        "AND text LIKE ? "
        "ORDER BY timestamp ASC",
        (f"%{MARKER}%",),
    )

    events: list[tuple[int, str, str]] = []
    last_sig: str | None = None
    last_seen_ts_by_sig: dict[str, int] = {}
    for (timestamp, text) in cursor:
        idx = text.find(MARKER)
        if idx <= 0:
            continue
        query = extract_query_from_google_url(text)
        if not query:
            continue
        ts = int(timestamp)
        # Use `ved` as the page signature; if missing, fall back to query.
        m = VED_RE.search(text)
        ved = m.group(1) if m else ""
        sig = ved if ved else ("no_ved|" + query)

        if sig == last_sig:
            continue

        prev_ts = last_seen_ts_by_sig.get(sig)
        if prev_ts is not None:
            gap = ts - prev_ts
            # Suppress "moderate-delay flashback" duplicates.
            if gap >= revisit_suppress_min_ms and gap < revisit_suppress_max_ms:
                continue

        last_sig = sig
        last_seen_ts_by_sig[sig] = ts
        events.append((ts, query, sig))

    conn.close()

    # Post-filter "query flashback" noise:
    # sometimes a previously seen query reappears briefly right before the
    # real next query. If a repeated query is followed very quickly by a
    # different query, drop that repeated one.
    seen_queries: set[str] = set()
    last_seen_ts_by_query: dict[str, int] = {}
    filtered: list[tuple[int, str, str]] = []
    for i, (ts, query, sig) in enumerate(events):
        next_event = events[i + 1] if i + 1 < len(events) else None
        if query in seen_queries and next_event is not None:
            next_ts, next_query, _next_sig = next_event
            if next_query != query and (next_ts - ts) <= FLASHBACK_NEXT_WINDOW_MS:
                continue

        # Suppress late query flashbacks:
        # the same old query can briefly reappear minutes later while navigating,
        # then quickly transitions to a different new query.
        prev_q_ts = last_seen_ts_by_query.get(query)
        if prev_q_ts is not None and next_event is not None:
            next_ts, next_query, _next_sig = next_event
            q_gap = ts - prev_q_ts
            if (
                next_query != query
                and QUERY_FLASHBACK_MIN_GAP_MS <= q_gap < QUERY_FLASHBACK_MAX_GAP_MS
                and (next_ts - ts) <= QUERY_FLASHBACK_NEXT_WINDOW_MS
            ):
                continue

        filtered.append((ts, query, sig))
        seen_queries.add(query)
        last_seen_ts_by_query[query] = ts

    return filtered


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Extract Google search queries from screentext*.db (data-driven).")
    parser.add_argument("db_path", nargs="?", default="screentext.db")
    parser.add_argument("--table", default=None, help="Optional: specify screentext table name (default: screentext or latest screentextN).")
    parser.add_argument("--revisit-suppress-min-ms", type=int, default=REVISIT_SUPPRESS_MIN_MS)
    parser.add_argument("--revisit-suppress-max-ms", type=int, default=REVISIT_SUPPRESS_MAX_MS)
    args = parser.parse_args()

    conn = sqlite3.connect(args.db_path)
    try:
        # For per-export DBs, it's just "screentext". For older combined exports, try latest screentextN.
        table_name = args.table if args.table else choose_latest_screentext_table_name(conn)
    finally:
        conn.close()

    events = extract_chrome_events(
        args.db_path,
        table_name,
        revisit_suppress_min_ms=args.revisit_suppress_min_ms,
        revisit_suppress_max_ms=args.revisit_suppress_max_ms,
    )

    queries = [q for _, q, _ in events]
    print(f"DB: {args.db_path}")
    print(f"Table: {table_name}")
    print(f"Found {len(queries)} tracked search queries:\n")
    for i, q in enumerate(queries, 1):
        print(f"  {i}. {q}")
