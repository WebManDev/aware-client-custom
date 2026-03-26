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
BING_URL_MARKER = "bing.com/search?q="
YAHOO_RESULTS_MARKER = "Yahoo Search Results"

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
BING_Q_RE = re.compile(r"bing\.com/search\?q=([^&*\s]+)")
BING_CVID_RE = re.compile(r"[?&]cvid=([^&*\s]+)")
YAHOO_Q_URL_RE = re.compile(r"search\?p=([^&*\s;]+)")
YAHOO_YLT_RE = re.compile(r"_ylt=([^;&*\s]+)")


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


def extract_query_from_bing_url(chrome_text: str) -> str:
    """
    Extract the user's query from Bing search URLs in the ScreenText blob.
    """
    m = BING_Q_RE.search(chrome_text)
    if not m:
        return ""
    raw = m.group(1)
    return unquote(unquote(raw)).replace('+', ' ').strip()


def extract_query_from_yahoo_text(chrome_text: str) -> str:
    """
    Extract the query from Yahoo search captures.

    Your blobs contain either:
    - URL fragments like: au.search.yahoo.com/search?p=<query>
    - Title fragments like: <query> - Yahoo Search Results
    """
    m = YAHOO_Q_URL_RE.search(chrome_text)
    if m:
        raw = m.group(1)
        return unquote(unquote(raw)).replace('+', ' ').strip()

    marker = " - Yahoo Search Results"
    if marker in chrome_text:
        # In ScreenText, the title is usually at the beginning of the accessibility blob.
        q = chrome_text.split(marker, 1)[0].strip()
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


def extract_bing_events(db_path: str, table_name: str) -> list[tuple[int, str, str]]:
    """
    Extract Bing search events as (timestamp_ms, query, signature).

    We only use rows that contain a Bing search URL, then dedupe by signature.
    Signature preference: cvid token, fallback to query.
    """
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute(
        "SELECT timestamp, text FROM " + table_name + " "
        "WHERE package_name = 'com.android.chrome' "
        "AND text LIKE ? "
        "ORDER BY timestamp ASC",
        (f"%{BING_URL_MARKER}%",),
    )

    events: list[tuple[int, str, str]] = []
    last_sig: str | None = None
    for (timestamp, text) in cursor:
        query = extract_query_from_bing_url(text)
        if not query:
            continue
        ts = int(timestamp)
        m = BING_CVID_RE.search(text)
        cvid = m.group(1) if m else ""
        sig = cvid if cvid else ("no_cvid|" + query)
        if sig == last_sig:
            continue
        last_sig = sig
        events.append((ts, query, sig))

    conn.close()
    return events


def extract_yahoo_events(db_path: str, table_name: str) -> list[tuple[int, str, str]]:
    """
    Extract Yahoo search events as (timestamp_ms, query, signature).

    First pass heuristic (for your current Yahoo DBs):
    - Keep Chrome rows whose text contains "Yahoo Search Results"
    - Extract the query from either `search?p=` in the URL or "<q> - Yahoo Search Results"
    - Dedupe to avoid overcounting ScreenText snapshots:
      if the same query repeats consecutively within <REVISIT_SUPPRESS_MIN_MS, ignore it.
    - Signature is `_ylt` when present; otherwise fall back to the query.
    """
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute(
        "SELECT timestamp, text FROM " + table_name + " "
        "WHERE package_name = 'com.android.chrome' "
        "AND text LIKE ? "
        "ORDER BY timestamp ASC",
        (f"%{YAHOO_RESULTS_MARKER}%",),
    )

    events: list[tuple[int, str, str]] = []
    last_query: str | None = None
    last_query_ts: int | None = None

    for (timestamp, text) in cursor:
        query = extract_query_from_yahoo_text(text)
        if not query:
            continue

        ts = int(timestamp)

        # Consecutive duplicate query snapshots: treat as re-capture unless enough time passed.
        if last_query == query and last_query_ts is not None:
            gap = ts - last_query_ts
            if gap < REVISIT_SUPPRESS_MIN_MS:
                continue

        m = YAHOO_YLT_RE.search(text)
        ylt = m.group(1) if m else ""
        sig = ylt if ylt else ("no_ylt|" + query)

        events.append((ts, query, sig))
        last_query = query
        last_query_ts = ts

    conn.close()

    # Post-filter Yahoo-specific query flashback noise.
    # Yahoo pages can briefly re-expose a prior query right before the next
    # navigation; this looks like a repeated search but should be ignored.
    seen_queries: set[str] = set()
    last_seen_ts_by_query: dict[str, int] = {}
    filtered: list[tuple[int, str, str]] = []
    for i, (ts, query, sig) in enumerate(events):
        next_event = events[i + 1] if i + 1 < len(events) else None
        if next_event is not None:
            next_ts, next_query, _next_sig = next_event
        else:
            next_ts, next_query = -1, ""

        if query in seen_queries and next_event is not None:
            if next_query != query and (next_ts - ts) <= FLASHBACK_NEXT_WINDOW_MS:
                continue

        prev_q_ts = last_seen_ts_by_query.get(query)
        if (
            prev_q_ts is not None
            and next_event is not None
            and next_query != query
        ):
            q_gap = ts - prev_q_ts
            if (
                QUERY_FLASHBACK_MIN_GAP_MS <= q_gap < QUERY_FLASHBACK_MAX_GAP_MS
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
    parser.add_argument("--engine", choices=["google", "bing", "yahoo"], default="google")
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

    if args.engine == "google":
        events = extract_chrome_events(
            args.db_path,
            table_name,
            revisit_suppress_min_ms=args.revisit_suppress_min_ms,
            revisit_suppress_max_ms=args.revisit_suppress_max_ms,
        )
    elif args.engine == "bing":
        events = extract_bing_events(args.db_path, table_name)
    else:
        events = extract_yahoo_events(args.db_path, table_name)

    queries = [q for _, q, _ in events]
    print(f"DB: {args.db_path}")
    print(f"Engine: {args.engine}")
    print(f"Table: {table_name}")
    print(f"Found {len(queries)} tracked search queries:\n")
    for i, q in enumerate(queries, 1):
        print(f"  {i}. {q}")
