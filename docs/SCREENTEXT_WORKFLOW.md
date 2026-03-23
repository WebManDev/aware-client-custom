# ScreenText Workflow

## Project structure

```
aware-client/
├── aware-core/src/main/java/com/aware/
│   ├── Aware.java                  # startScreenText(), stopScreenText()
│   ├── ScreenText.java             # Accessibility service that captures screen text
│   └── providers/ScreenText_Provider.java  # ContentProvider (live DB)
│
├── aware-tests/src/main/java/com/aware/tests/
│   ├── TestActivity.java           # Main menu (RUN/STOP SCREENTEXT, VIEW DATA)
│   └── ViewDataActivity.java       # View/export/clear data
│
├── extract_searches.py             # Parse Google searches from exported DBs
├── export-session.sh               # One-command: export + pull + extract
├── sync-exports.sh                 # Background watcher: auto-pulls exports to ~/Downloads
├── pull_screentext_dbs.sh          # Bulk pull all DBs from emulator
│
├── screentext_dbs/                 # Exported DBs (local Mac)
│   ├── session1_emu.db
│   └── session2_batman.db
│
├── GOOGLE_SEARCH_QUERIES.md        # Search protocol (what to type per session)
└── docs/
    ├── SCREENTEXT_WORKFLOW.md       # This file
    └── SCREENTEXT_SETUP.md         # Initial setup guide
```

## Buttons

### TestActivity.java — Main menu

| Button | Line | Function |
|--------|------|----------|
| RUN SCREENTEXT | 85–93 | `Aware.setSetting(STATUS_SCREENTEXT, true)` + `Aware.startScreenText()` |
| STOP SCREENTEXT | 95–103 | `Aware.setSetting(STATUS_SCREENTEXT, false)` + `Aware.stopScreenText()` |
| VIEW DATA | 105–111 | Opens `ViewDataActivity` |

### ViewDataActivity.java — Export screen

| Button | Line | Function |
|--------|------|----------|
| BACK | 124 | `finish()` |
| CLEAR DATA | 171 | `confirmAndClearAll()` — deletes all rows from ContentProvider. **No undo.** |
| EXPORT CSV / SQL | 200 | `exportScreenTextToCsvAndSql()` — writes `.csv` + `.sql` to `files/` |
| EXPORT TO SCREENTEXT.DB | 289 | `exportToSqliteDb()` — writes numbered `screentextN.db` to `files/` |

All exports copy to internal `files/` so `sync-exports.sh` and `adb` can access them.

Also supports remote trigger via `adb`:
```bash
adb shell "am start -a com.aware.tests.EXPORT_DB -n com.aware.tests/.ViewDataActivity"
```

## How to get files on your Mac

### Option 1: Auto-sync (recommended)

Start once, leave running:
```bash
bash sync-exports.sh
```
Now tap any export button on the emulator → file appears in **~/Downloads** automatically.

### Option 2: One-command export

```bash
bash export-session.sh session3_dog
```
Triggers export, pulls to `screentext_dbs/session3_dog.db`, runs extraction, opens Finder.

### Option 3: Manual pull

```bash
adb shell "run-as com.aware.tests ls files/"
adb exec-out run-as com.aware.tests cat files/screentext.db > screentext_dbs/my_session.db
```

## How to view data

```bash
# GUI
open -a "DB Browser for SQLite" screentext_dbs/session1_emu.db

# Terminal
sqlite3 screentext_dbs/session1_emu.db "SELECT timestamp, package_name, substr(text,1,100) FROM screentext LIMIT 10;"
```

## extract_searches.py

**What it does:** Reads a `.db`, finds Google Search results captured by Chrome, extracts the search queries, deduplicates.

```bash
python3 extract_searches.py screentext_dbs/session2_batman.db
python3 extract_searches.py screentext_dbs/session2_batman.db --table screentext
```

**Functions:**

| Function | What it does |
|----------|-------------|
| `extract_query_from_google_url(text)` | Pulls `q=` from the Google URL in a ScreenText blob. Decodes twice. |
| `choose_latest_screentext_table_name(conn)` | Picks `screentext` or highest `screentextN` table in the DB. |
| `extract_chrome_events(db_path, table)` | Main pipeline. Queries Chrome rows with `" - Google Search"`, extracts query + `ved` signature, collapses duplicates. |

**Dedup logic** (in `extract_chrome_events`):
- Same `ved` signature back-to-back → skip (same page re-captured)
- Same signature reappears 8–60s later → skip (Chrome flashback)
- Same signature after 60s+ → count it (real repeat search)

**Known gaps:**
- Queries only visible in tab-switcher snippets (no URL) get skipped
- Google truncates long queries with special chars in the URL

## Emulator commands

```bash
# Start
~/Library/Android/sdk/emulator/emulator -avd Medium_Phone_API_36.0 &

# Check
adb devices

# List files on device
adb shell "run-as com.aware.tests ls files/"

# Pull one file
adb exec-out run-as com.aware.tests cat files/screentext.db > local.db
```

## WARNING

**Export before you clear.** Clear permanently deletes all data from the ContentProvider. If you clear first, the export will have nothing.
