package com.getcapacitor.community.database.sqlite;

import static org.junit.Assert.*;

import android.content.Context;
import android.util.Log;
import androidx.test.ext.junit.runners.AndroidJUnit4;
import androidx.test.platform.app.InstrumentationRegistry;
import com.getcapacitor.JSArray;
import com.getcapacitor.JSObject;
import com.getcapacitor.community.database.sqlite.SQLite.Database;
import com.getcapacitor.community.database.sqlite.SQLite.SqliteConfig;
import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.Hashtable;
import org.json.JSONObject;
import org.junit.Test;
import org.junit.runner.RunWith;

@RunWith(AndroidJUnit4.class)
public class ImportFromJsonBasicInstrumentedTest {

    private String loadJsonFromAssets(Context context, String name) throws Exception {
        InputStream is = context.getAssets().open(name);
        BufferedReader br = new BufferedReader(new InputStreamReader(is, StandardCharsets.UTF_8));
        StringBuilder sb = new StringBuilder();
        String line;
        while ((line = br.readLine()) != null) {
            sb.append(line).append('\n');
        }
        br.close();
        return sb.toString();
    }

    @Test
    public void importFromJson_basic() throws Exception {
        Context context = InstrumentationRegistry.getInstrumentation().getTargetContext();
        final String TAG = "ImportFromJsonTest";
        long totalStartMs = android.os.SystemClock.elapsedRealtime();

        // Place basic.json into android/app/src/main/assets/ or this module's assets via test APK assets merging
        String json = loadJsonFromAssets(context, "basic.json");
        assertTrue(json.contains("testjson_file"));

        CapacitorSQLite cap = new CapacitorSQLite(context, new SqliteConfig());
        // Validate JSON
        assertTrue(cap.isJsonValid(json));

        // Import with timing
        long startMs = android.os.SystemClock.elapsedRealtime();
        JSObject res = cap.importFromJson(json);
        assertNotNull(res);
        assertTrue(res.getInteger("changes") >= 0);

        // Open and query via Database helper
        String dbName = "testjson_fileSQLite.db";
        Database db = new Database(context, dbName, 1, new Hashtable<Integer, JSONObject>(), false);
        db.open();
        JSArray rows = db.selectSQL("SELECT COUNT(*) AS cnt FROM users", new java.util.ArrayList<>());
        assertTrue(rows.length() > 0);
        int cnt = rows.getJSONObject(rows.length() - 1).getInt("cnt");
        assertEquals(2, cnt);
        db.close();
        long elapsedMs = android.os.SystemClock.elapsedRealtime() - startMs;
        System.out.println("[TEST] importFromJson took " + elapsedMs + "ms");
        Log.i(TAG, "importFromJson took " + elapsedMs + "ms");
        long totalElapsedMs = android.os.SystemClock.elapsedRealtime() - totalStartMs;
        System.out.println("[TEST] importFromJson_basic total elapsed " + totalElapsedMs + "ms");
        Log.i(TAG, "importFromJson_basic total elapsed " + totalElapsedMs + "ms");
        assertTrue("importFromJson_basic exceeded 100, elapsed=" + totalElapsedMs + "ms", totalElapsedMs <= 100);
    }

    @Test
    public void query_all_tables_with_timing() throws Exception {
        Context context = InstrumentationRegistry.getInstrumentation().getTargetContext();
        final String TAG = "ImportFromJsonTest";
        //        Copy Quartermaster4SQLite.db from assets (public/assets/databases) into databases dir
        //        and open it (UtilsFile.copyFromAssetsToDatabase adds SQLite suffix automatically)
        com.getcapacitor.community.database.sqlite.SQLite.UtilsFile uFile =
            new com.getcapacitor.community.database.sqlite.SQLite.UtilsFile();
        // Overwrite to ensure fresh copy for timing
        uFile.copyFromAssetsToDatabase(context, true);
        String dbName = "Quartermaster4SQLite.db";
        Database db = new Database(context, dbName, 1, new Hashtable<Integer, JSONObject>(), false);

        long totalStart = android.os.SystemClock.elapsedRealtime();
        db.open();
        JSArray tables = db.getTableNames();
        System.out.println("[TEST] tables count=" + tables.length());
        Log.i(TAG, "tables count=" + tables.length());
        for (int i = 0; i < tables.length(); i++) {
            String table = tables.getString(i);
            long tCountStart = android.os.SystemClock.elapsedRealtime();
            JSArray countRows = db.selectSQL("SELECT COUNT(*) AS cnt FROM " + table, new java.util.ArrayList<>());
            long tCount = android.os.SystemClock.elapsedRealtime() - tCountStart;
            int cnt = countRows.getJSONObject(countRows.length() - 1).getInt("cnt");
            System.out.println("[TEST] table=" + table + " count=" + cnt + " (" + tCount + "ms)");
            Log.i(TAG, "table=" + table + " count=" + cnt + " (" + tCount + "ms)");

            long tSelStart = android.os.SystemClock.elapsedRealtime();
            JSArray allRows = db.selectSQL("SELECT * FROM " + table, new java.util.ArrayList<>());
            long tSel = android.os.SystemClock.elapsedRealtime() - tSelStart;
            System.out.println("[TEST] table=" + table + " full select rows=" + allRows.length() + " (" + tSel + "ms)");
            Log.i(TAG, "table=" + table + " full select rows=" + allRows.length() + " (" + tSel + "ms)");
        }
        db.close();
        long totalElapsed = android.os.SystemClock.elapsedRealtime() - totalStart;
        System.out.println("[TEST] query_all_tables_with_timing total elapsed " + totalElapsed + "ms");
        Log.i(TAG, "query_all_tables_with_timing total elapsed " + totalElapsed + "ms");
        assertTrue("importFromJson_basic exceeded 500ms, elapsed=" + totalElapsed + "ms", totalElapsed <= 500);
    }
}
