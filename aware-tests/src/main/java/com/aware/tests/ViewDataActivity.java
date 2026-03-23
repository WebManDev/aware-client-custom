package com.aware.tests;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.DialogInterface;
import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;
import android.os.Environment;
import android.view.View;
import android.widget.Button;
import android.widget.ListView;
import android.widget.ScrollView;
import android.widget.SimpleAdapter;
import android.widget.TextView;
import android.widget.Toast;
import com.aware.providers.ScreenText_Provider;

import android.database.sqlite.SQLiteDatabase;

import java.io.File;
import java.io.FileOutputStream;
import java.io.OutputStreamWriter;
import java.nio.charset.StandardCharsets;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

public class ViewDataActivity extends Activity {

    private final List<Map<String, String>> rows = new ArrayList<Map<String, String>>();
    private SimpleAdapter adapter;
    private TextView txtCount;
    private ListView list;
    private Uri uri;

    private static final String ACTION_EXPORT_DB = "com.aware.tests.EXPORT_DB";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        uri = Uri.parse("content://" + getPackageName() + ".provider.screentext/screentext");

        if (getIntent() != null && ACTION_EXPORT_DB.equals(getIntent().getAction())) {
            exportToSqliteDb();
            finish();
            return;
        }

        setContentView(R.layout.activity_view_data);

        txtCount = findViewById(R.id.txt_count);
        list = findViewById(R.id.list_data);
        Button btnBack = findViewById(R.id.btn_back);
        Button btnExport = findViewById(R.id.btn_export);
        Button btnExportDb = findViewById(R.id.btn_export_db);
        Button btnClear = findViewById(R.id.btn_clear);

        adapter = new SimpleAdapter(
                this,
                rows,
                R.layout.item_screentext_row,
                new String[]{"pkg", "ts", "text"},
                new int[]{R.id.row_pkg, R.id.row_ts, R.id.row_text}
        );
        list.setAdapter(adapter);

        list.setOnItemClickListener(new android.widget.AdapterView.OnItemClickListener() {
            @Override
            public void onItemClick(android.widget.AdapterView<?> parent, View view, int position, long id) {
                Map<String, String> row = rows.get(position);
                String pkg = row.get("pkg");
                String ts = row.get("ts");
                String fullText = row.get("fulltext");

                TextView content = new TextView(ViewDataActivity.this);
                content.setPadding(40, 30, 40, 30);
                content.setTextSize(14);
                content.setText(pkg + "\n\n" + ts + "\n\n" + fullText);
                content.setTextIsSelectable(true);

                ScrollView scroll = new ScrollView(ViewDataActivity.this);
                scroll.addView(content);

                new AlertDialog.Builder(ViewDataActivity.this)
                        .setTitle("Full entry")
                        .setView(scroll)
                        .setPositiveButton("OK", null)
                        .show();
            }
        });

        loadRows();

        btnExport.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                exportScreenTextToCsvAndSql();
            }
        });

        btnExportDb.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                exportToSqliteDb();
            }
        });

        btnClear.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                confirmAndClearAll();
            }
        });

        btnBack.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                finish();
            }
        });
    }

    private void loadRows() {
        rows.clear();

        Cursor c = null;
        try {
            c = getContentResolver().query(
                    uri,
                    null,
                    null,
                    null,
                    ScreenText_Provider.ScreenTextData.TIMESTAMP + " DESC"
            );
            if (c != null && c.moveToFirst()) {
                int pkgIdx = c.getColumnIndex(ScreenText_Provider.ScreenTextData.PACKAGE_NAME);
                int tsIdx = c.getColumnIndex(ScreenText_Provider.ScreenTextData.TIMESTAMP);
                int textIdx = c.getColumnIndex(ScreenText_Provider.ScreenTextData.TEXT);
                do {
                    Map<String, String> row = new HashMap<String, String>();
                    String pkg = pkgIdx >= 0 ? c.getString(pkgIdx) : "";
                    String ts = tsIdx >= 0 ? String.valueOf(c.getLong(tsIdx)) : "";
                    String fullText = textIdx >= 0 ? c.getString(textIdx) : "";
                    if (fullText == null) fullText = "";
                    row.put("pkg", pkg);
                    row.put("ts", ts);
                    row.put("fulltext", fullText);
                    row.put("text", fullText.length() > 200 ? fullText.substring(0, 200) + "..." : fullText);
                    rows.add(row);
                } while (c.moveToNext());
            }
        } catch (Exception e) {
            Toast.makeText(this, "Error: " + e.getMessage(), Toast.LENGTH_SHORT).show();
        } finally {
            if (c != null) c.close();
        }

        txtCount.setText("ScreenText rows: " + rows.size() + " (tap a row to see full text)");
        if (rows.isEmpty()) {
            txtCount.append("\nNo data yet. Run ScreenText, enable Accessibility, then use the device.");
        }
        if (adapter != null) adapter.notifyDataSetChanged();
    }

    private void confirmAndClearAll() {
        if (rows.isEmpty()) {
            Toast.makeText(this, "No data to clear.", Toast.LENGTH_SHORT).show();
            return;
        }

        new AlertDialog.Builder(this)
                .setTitle("Clear all data?")
                .setMessage("This will permanently delete all ScreenText rows collected so far on this device/emulator.")
                .setNegativeButton("Cancel", null)
                .setPositiveButton("Clear", new DialogInterface.OnClickListener() {
                    @Override
                    public void onClick(DialogInterface dialog, int which) {
                        try {
                            int deleted = getContentResolver().delete(uri, null, null);
                            Toast.makeText(ViewDataActivity.this, "Deleted " + deleted + " rows.", Toast.LENGTH_SHORT).show();
                        } catch (Exception e) {
                            Toast.makeText(ViewDataActivity.this, "Clear failed: " + e.getMessage(), Toast.LENGTH_LONG).show();
                        }
                        loadRows();
                    }
                })
                .show();
    }

    /**
     * Exports all ScreenText data from the ContentProvider to CSV and SQL files.
     * Files are saved in the app's Documents folder (visible via Device File Explorer or adb pull).
     */
    private void exportScreenTextToCsvAndSql() {
        Cursor c = null;
        File dir = getExternalFilesDir(Environment.DIRECTORY_DOCUMENTS);
        if (dir == null) {
            Toast.makeText(this, "Cannot access storage.", Toast.LENGTH_LONG).show();
            return;
        }
        String dateStr = new SimpleDateFormat("yyyy-MM-dd_HHmmss", Locale.US).format(new Date());
        File csvFile = new File(dir, "screentext_export_" + dateStr + ".csv");
        File sqlFile = new File(dir, "screentext_export_" + dateStr + ".sql");

        try {
            c = getContentResolver().query(uri, null, null, null,
                    ScreenText_Provider.ScreenTextData.TIMESTAMP + " ASC");
            if (c == null || !c.moveToFirst()) {
                Toast.makeText(this, "No data to export.", Toast.LENGTH_SHORT).show();
                return;
            }

            int idIdx = c.getColumnIndex(ScreenText_Provider.ScreenTextData._ID);
            int tsIdx = c.getColumnIndex(ScreenText_Provider.ScreenTextData.TIMESTAMP);
            int devIdx = c.getColumnIndex(ScreenText_Provider.ScreenTextData.DEVICE_ID);
            int classIdx = c.getColumnIndex(ScreenText_Provider.ScreenTextData.CLASS_NAME);
            int pkgIdx = c.getColumnIndex(ScreenText_Provider.ScreenTextData.PACKAGE_NAME);
            int textIdx = c.getColumnIndex(ScreenText_Provider.ScreenTextData.TEXT);
            int actionIdx = c.getColumnIndex(ScreenText_Provider.ScreenTextData.USER_ACTION);
            int eventIdx = c.getColumnIndex(ScreenText_Provider.ScreenTextData.EVENT_TYPE);

            StringBuilder csv = new StringBuilder();
            StringBuilder sql = new StringBuilder();
            sql.append("-- ScreenText export - import into MySQL/PostgreSQL\n");
            sql.append("CREATE TABLE IF NOT EXISTS screentext (\n");
            sql.append("  _id INTEGER PRIMARY KEY,\n");
            sql.append("  timestamp REAL,\n");
            sql.append("  device_id TEXT,\n");
            sql.append("  class_name TEXT,\n");
            sql.append("  package_name TEXT,\n");
            sql.append("  text LONGTEXT,\n");
            sql.append("  user_action INTEGER,\n");
            sql.append("  event_type INTEGER\n");
            sql.append(");\n\n");

            csv.append("_id,timestamp,device_id,class_name,package_name,text,user_action,event_type\n");

            int count = 0;
            do {
                long id = idIdx >= 0 ? c.getLong(idIdx) : 0;
                long ts = tsIdx >= 0 ? c.getLong(tsIdx) : 0;
                String dev = devIdx >= 0 ? nullToEmpty(c.getString(devIdx)) : "";
                String cls = classIdx >= 0 ? nullToEmpty(c.getString(classIdx)) : "";
                String pkg = pkgIdx >= 0 ? nullToEmpty(c.getString(pkgIdx)) : "";
                String text = textIdx >= 0 ? nullToEmpty(c.getString(textIdx)) : "";
                int action = actionIdx >= 0 ? c.getInt(actionIdx) : 0;
                int event = eventIdx >= 0 ? c.getInt(eventIdx) : 0;

                csv.append(id).append(",");
                csv.append(ts).append(",");
                csv.append(escapeCsv(dev)).append(",");
                csv.append(escapeCsv(cls)).append(",");
                csv.append(escapeCsv(pkg)).append(",");
                csv.append(escapeCsv(text)).append(",");
                csv.append(action).append(",");
                csv.append(event).append("\n");

                String textEsc = escapeSql(text);
                String devEsc = escapeSql(dev);
                String clsEsc = escapeSql(cls);
                String pkgEsc = escapeSql(pkg);
                sql.append("INSERT INTO screentext (_id,timestamp,device_id,class_name,package_name,text,user_action,event_type) VALUES (");
                sql.append(id).append(",").append(ts).append(",'").append(devEsc).append("','").append(clsEsc).append("','").append(pkgEsc).append("','").append(textEsc).append("',").append(action).append(",").append(event).append(");\n");
                count++;
            } while (c.moveToNext());

            writeFile(csvFile, csv.toString());
            writeFile(sqlFile, sql.toString());

            copyFile(csvFile, new File(getFilesDir(), csvFile.getName()));
            copyFile(sqlFile, new File(getFilesDir(), sqlFile.getName()));

            Toast.makeText(this, "Exported " + count + " rows:\n" + csvFile.getName() + "\n" + sqlFile.getName(), Toast.LENGTH_LONG).show();
        } catch (Exception e) {
            Toast.makeText(this, "Export failed: " + e.getMessage(), Toast.LENGTH_LONG).show();
        } finally {
            if (c != null) c.close();
        }
    }

    private void exportToSqliteDb() {
        File dir = getExternalFilesDir(Environment.DIRECTORY_DOCUMENTS);
        if (dir == null) {
            Toast.makeText(this, "Cannot access storage.", Toast.LENGTH_LONG).show();
            return;
        }
        // Export each run into a new numbered file:
        // screentext.db, screentext2.db, screentext3.db, ...
        int maxIdx = 0;
        File[] files = dir.listFiles();
        if (files != null) {
            for (File f : files) {
                if (f == null) continue;
                String name = f.getName();
                if (name == null) continue;
                if (name.equals("screentext.db")) {
                    if (maxIdx < 1) maxIdx = 1;
                    continue;
                }
                if (name.startsWith("screentext") && name.endsWith(".db")) {
                    String mid = name.substring("screentext".length(), name.length() - ".db".length());
                    try {
                        int idx = Integer.parseInt(mid);
                        if (idx > maxIdx) maxIdx = idx;
                    } catch (NumberFormatException ignored) {}
                }
            }
        }

        int nextIdx = maxIdx + 1; // if none exist -> 1
        String filename = (nextIdx == 1) ? "screentext.db" : ("screentext" + nextIdx + ".db");

        File dbFile = new File(dir, filename);
        File internalCopy = new File(getFilesDir(), filename);

        Cursor c = null;
        SQLiteDatabase db = null;
        try {
            c = getContentResolver().query(uri, null, null, null,
                    ScreenText_Provider.ScreenTextData.TIMESTAMP + " ASC");
            if (c == null || !c.moveToFirst()) {
                Toast.makeText(this, "No data to export.", Toast.LENGTH_SHORT).show();
                return;
            }
            if (dbFile.exists()) dbFile.delete();
            db = SQLiteDatabase.openOrCreateDatabase(dbFile, null);

            db.execSQL("CREATE TABLE IF NOT EXISTS screentext ("
                    + "_id INTEGER PRIMARY KEY,"
                    + "timestamp REAL,"
                    + "device_id TEXT,"
                    + "class_name TEXT,"
                    + "package_name TEXT,"
                    + "text TEXT,"
                    + "user_action INTEGER,"
                    + "event_type INTEGER"
                    + ")");

            int idIdx = c.getColumnIndex(ScreenText_Provider.ScreenTextData._ID);
            int tsIdx = c.getColumnIndex(ScreenText_Provider.ScreenTextData.TIMESTAMP);
            int devIdx = c.getColumnIndex(ScreenText_Provider.ScreenTextData.DEVICE_ID);
            int classIdx = c.getColumnIndex(ScreenText_Provider.ScreenTextData.CLASS_NAME);
            int pkgIdx = c.getColumnIndex(ScreenText_Provider.ScreenTextData.PACKAGE_NAME);
            int textIdx = c.getColumnIndex(ScreenText_Provider.ScreenTextData.TEXT);
            int actionIdx = c.getColumnIndex(ScreenText_Provider.ScreenTextData.USER_ACTION);
            int eventIdx = c.getColumnIndex(ScreenText_Provider.ScreenTextData.EVENT_TYPE);

            db.beginTransaction();
            int count = 0;
            do {
                android.content.ContentValues row = new android.content.ContentValues();
                if (idIdx >= 0) row.put("_id", c.getLong(idIdx));
                if (tsIdx >= 0) row.put("timestamp", c.getLong(tsIdx));
                if (devIdx >= 0) row.put("device_id", c.getString(devIdx));
                if (classIdx >= 0) row.put("class_name", c.getString(classIdx));
                if (pkgIdx >= 0) row.put("package_name", c.getString(pkgIdx));
                if (textIdx >= 0) row.put("text", c.getString(textIdx));
                if (actionIdx >= 0) row.put("user_action", c.getInt(actionIdx));
                if (eventIdx >= 0) row.put("event_type", c.getInt(eventIdx));
                db.insertWithOnConflict("screentext", null, row, SQLiteDatabase.CONFLICT_REPLACE);
                count++;
            } while (c.moveToNext());
            db.setTransactionSuccessful();
            db.endTransaction();

            Toast.makeText(this, "Exported " + count + " rows to:\n" + dbFile.getAbsolutePath(), Toast.LENGTH_LONG).show();

            copyFile(dbFile, internalCopy);
        } catch (Exception e) {
            Toast.makeText(this, "DB export failed: " + e.getMessage(), Toast.LENGTH_LONG).show();
        } finally {
            if (c != null) c.close();
            if (db != null) db.close();
        }
    }

    private static void copyFile(File src, File dst) {
        try {
            java.io.FileInputStream in = new java.io.FileInputStream(src);
            java.io.FileOutputStream out = new java.io.FileOutputStream(dst);
            byte[] buf = new byte[8192];
            int len;
            while ((len = in.read(buf)) > 0) out.write(buf, 0, len);
            in.close();
            out.close();
        } catch (Exception ignored) {}
    }

    private static String nullToEmpty(String s) {
        return s == null ? "" : s;
    }

    private static String escapeCsv(String value) {
        if (value == null) return "\"\"";
        if (value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r")) {
            return "\"" + value.replace("\"", "\"\"") + "\"";
        }
        return value;
    }

    private static String escapeSql(String value) {
        if (value == null) return "";
        return value.replace("\\", "\\\\").replace("'", "''").replace("\r", " ").replace("\n", " ");
    }

    private void writeFile(File file, String content) throws java.io.IOException {
        FileOutputStream fos = new FileOutputStream(file);
        OutputStreamWriter w = new OutputStreamWriter(fos, StandardCharsets.UTF_8);
        w.write(content);
        w.close();
        fos.close();
    }
}
