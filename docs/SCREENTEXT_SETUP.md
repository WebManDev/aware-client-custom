# Following AWARE Screentext Documentation

How to use the Screentext sensor in this client according to the [AWARE Screentext docs](https://awareframework.com/screentext/).

---

## 1. Enable the sensor

**Setting:** `Aware_Preferences.SCREENTEXT` = `true`

**In this app:**
- **Test app:** Tap **"Run ScreenText"** (it sets this and starts the service).
- **Or in code:**
  ```java
  Aware.setSetting(context, Aware_Preferences.STATUS_SCREENTEXT, true);
  Aware.startScreenText(context);
  ```

---

## 2. Optional: Limit which apps are tracked

**Settings:**

| Setting | Key | Values | Meaning |
|--------|-----|--------|---------|
| Package mode | `Aware_Preferences.PACKAGE_SPECIFICATION` | `0` | Only track **inclusive** apps (list in PACKAGE_NAMES) |
| | | `1` | Track all **except** apps in PACKAGE_NAMES |
| | | `2` | Track **all** applications (default) |
| App list | `Aware_Preferences.PACKAGE_NAMES` | e.g. `"com.instagram.android, com.facebook.katana"` | Comma- or space-separated package names |

**In code (e.g. before starting ScreenText):**
```java
// Only track these apps:
Aware.setSetting(context, Aware_Preferences.PACKAGE_SPECIFICATION, "0");
Aware.setSetting(context, Aware_Preferences.PACKAGE_NAMES, "com.instagram.android, com.aware.phone");

// Or: track all except these:
Aware.setSetting(context, Aware_Preferences.PACKAGE_SPECIFICATION, "1");
Aware.setSetting(context, Aware_Preferences.PACKAGE_NAMES, "com.android.settings");
```

---

## 3. Turn on Accessibility (required for capture)

Screentext runs inside the **Applications** accessibility service. You must enable it:

1. Open **Settings → Accessibility** on the device/emulator.
2. Find **AWARE** (or your app name, e.g. **AWARE Tests**).
3. Turn it **On** and accept the permission.

Without this, the sensor is “on” but no screen text is captured.

---

## 4. Read the data

**Provider (from docs):**  
`content://com.aware.provider.screentext/screentext`  
In this app the authority is your package, so:

- Test app: `content://com.aware.tests.provider.screentext/screentext`
- Main app: `content://com.aware.phone.provider.screentext/screentext`

**In the test app:** Tap **"View data"** to see recent ScreenText rows.

**In code:**
```java
Uri uri = Uri.parse("content://" + getPackageName() + ".provider.screentext/screentext");
Cursor c = getContentResolver().query(uri, null, null, null, "timestamp DESC");
// use cursor: _id, timestamp, device_id, class_name, package_name, text, user_action, event_type
```

**Broadcast (from docs):** When new text is detected:
- Action: `ScreenText.ACTION_SCREENTEXT_DETECT`
- Register a `BroadcastReceiver` for this action if you want to react in real time.

---

## 5. Checklist (in order)

1. Enable Screentext: `STATUS_SCREENTEXT = true` and `Aware.startScreenText(context)` (or tap **Run ScreenText** in the test app).
2. Optionally set `PACKAGE_SPECIFICATION` and `PACKAGE_NAMES` if you don’t want “all apps”.
3. Enable **AWARE** (or your app) under **Settings → Accessibility**.
4. Use the device; data is written to the provider and `ACTION_SCREENTEXT_DETECT` is broadcast.
5. View data via **View data** button or by querying the provider URI above.

Password fields are not recorded; the doc’s “Checklist of Password Detection” applies to the show-password feature in apps.

---

## 6. Testing ScreenText and collecting data

### Quick test (test app)

1. **Run the test app** (e.g. `aware-tests` module, run on emulator or device).
2. Tap **"Run ScreenText"** — this enables the sensor and starts the service.
3. Go to **Settings → Accessibility** and turn **ON** the entry for **AWARE Tests** (or your app name). Accept the permission.
4. Use the device: open other apps, tap around. Screen text is captured in the background.
5. In the test app, tap **"View data"** to see captured rows (package name, timestamp, text). Tap a row to see full text.

Data is **already stored in a SQLite database** on the device: table `screentext` in `screentext.db`, managed by `ScreenText_Provider`.

### Export to CSV and SQL (for analysis or MySQL)

1. After viewing data, tap **"Export to CSV / SQL"** in the View data screen.
2. Two files are written in the app's **Documents** folder:
   - `screentext_export_YYYY-MM-DD_HHmmss.csv` — CSV (open in Excel or import into any DB).
   - `screentext_export_YYYY-MM-DD_HHmmss.sql` — SQL with `CREATE TABLE` and `INSERT` statements.

3. **Where are the files?**
   - Path shown in the toast (e.g. `/storage/emulated/0/Android/data/com.aware.tests/files/Documents`).
   - **Android Studio:** Device File Explorer → select device → browse to that path.
   - **Command line:** `adb pull /storage/emulated/0/Android/data/com.aware.tests/files/Documents ./screentext_export`

### Import into MySQL (or another SQL database)

**Option A – Use the generated .sql file**

1. Pull the `.sql` file to your computer (see above).
2. Create the database and run the script:
   ```bash
   mysql -u your_user -p -e "CREATE DATABASE IF NOT EXISTS aware_screentext;"
   mysql -u your_user -p aware_screentext < screentext_export_2025-02-03_123456.sql
   ```

**Option B – Use the CSV file**

1. Pull the `.csv` file to your computer.
2. Create the table (same schema as in the .sql file):
   ```sql
   CREATE TABLE screentext (
     _id INT PRIMARY KEY,
     timestamp DOUBLE,
     device_id VARCHAR(255),
     class_name TEXT,
     package_name VARCHAR(255),
     text LONGTEXT,
     user_action INT,
     event_type INT
   );
   ```
3. Load the CSV (MySQL example; adjust path and column list as needed):
   ```sql
   LOAD DATA LOCAL INFILE '/path/to/screentext_export_2025-02-03_123456.csv'
   INTO TABLE screentext
   FIELDS TERMINATED BY ',' ENCLOSED BY '"'
   LINES TERMINATED BY '\n'
   IGNORE 1 ROWS
   (_id, timestamp, device_id, class_name, package_name, text, user_action, event_type);
   ```

   Or use your DB's CSV import (e.g. MySQL Workbench, pgAdmin, etc.).

### Summary

| Step              | Action                                                                 |
|-------------------|------------------------------------------------------------------------|
| Test capture      | Run ScreenText → Enable Accessibility → Use device → View data        |
| Where data lives  | SQLite on device: `screentext.db` → table `screentext`                 |
| Export            | Tap "Export to CSV / SQL" → files in app Documents folder             |
| Get files to PC   | Device File Explorer or `adb pull` from path in toast                  |
| Put into MySQL    | Run the exported .sql file, or create table + `LOAD DATA` from CSV     |
