package com.getcapacitor.community.database.sqlite;

import static org.junit.Assert.*;

import android.content.Context;
import android.util.Log;
import androidx.test.ext.junit.runners.AndroidJUnit4;
import androidx.test.platform.app.InstrumentationRegistry;
import com.getcapacitor.JSArray;
import com.getcapacitor.JSObject;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import org.json.JSONArray;
import org.junit.Test;
import org.junit.runner.RunWith;

@RunWith(AndroidJUnit4.class)
public class ImportFromJsonBasicInstrumentedTest {

    private static final String TAG = "ImportFromJsonTest";

    private String loadJsonFromAssets(String name) throws Exception {
        // Test fixtures live in src/androidTest/assets so they don't ship with the library
        Context testContext = InstrumentationRegistry.getInstrumentation().getContext();
        InputStream is = testContext.getAssets().open(name);
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
        long totalStartMs = android.os.SystemClock.elapsedRealtime();

        String json = loadJsonFromAssets("basic.json");
        assertTrue(json.contains("testjson_file"));

        CapacitorSQLite cap = new CapacitorSQLite(context);
        // Validate JSON
        assertTrue(cap.isJsonValid(json));

        // Import with timing
        long startMs = android.os.SystemClock.elapsedRealtime();
        JSObject res = cap.importFromJson(json);
        assertNotNull(res);
        assertTrue(res.getInteger("changes") >= 0);

        // Open, query and export through the connection API
        String dbName = "testjson_file";
        cap.createConnection(dbName, 1);
        cap.open(dbName);
        JSArray rows = cap.query(dbName, "SELECT COUNT(*) AS cnt FROM users", new JSArray());
        assertTrue(rows.length() > 0);
        int cnt = rows.getJSONObject(rows.length() - 1).getInt("cnt");
        assertEquals(2, cnt);
        JSObject export = cap.exportToJson(dbName);
        assertEquals("testjson_file", export.getString("database"));
        JSONArray tables = export.getJSONArray("tables");
        assertEquals("users", tables.getJSONObject(0).getString("name"));
        assertEquals(2, tables.getJSONObject(0).getJSONArray("values").length());
        cap.close(dbName);
        cap.closeConnection(dbName);
        assertTrue(cap.isDatabase(dbName));

        long elapsedMs = android.os.SystemClock.elapsedRealtime() - startMs;
        System.out.println("[TEST] importFromJson took " + elapsedMs + "ms");
        Log.i(TAG, "importFromJson took " + elapsedMs + "ms");
        long totalElapsedMs = android.os.SystemClock.elapsedRealtime() - totalStartMs;
        System.out.println("[TEST] importFromJson_basic total elapsed " + totalElapsedMs + "ms");
        Log.i(TAG, "importFromJson_basic total elapsed " + totalElapsedMs + "ms");
        assertTrue("importFromJson_basic exceeded 500ms, elapsed=" + totalElapsedMs + "ms", totalElapsedMs <= 500);
    }

    @Test
    public void rejects_partial_json() throws Exception {
        Context context = InstrumentationRegistry.getInstrumentation().getTargetContext();
        CapacitorSQLite cap = new CapacitorSQLite(context);
        String json = loadJsonFromAssets("basic.json").replace("\"full\"", "\"partial\"");
        assertFalse(cap.isJsonValid(json));
        assertThrows(Exception.class, () -> cap.importFromJson(json));
    }

    @Test
    public void query_all_tables_with_timing() throws Exception {
        Context context = InstrumentationRegistry.getInstrumentation().getTargetContext();
        // Copy a fresh Quartermaster4SQLite.db into the databases dir when the fixture is present
        Context testContext = InstrumentationRegistry.getInstrumentation().getContext();
        if (Arrays.asList(testContext.getAssets().list("")).contains("Quartermaster4SQLite.db")) {
            File dbFile = context.getDatabasePath("Quartermaster4SQLite.db");
            dbFile.getParentFile().mkdirs();
            try (
                InputStream in = testContext.getAssets().open("Quartermaster4SQLite.db");
                OutputStream out = new FileOutputStream(dbFile)
            ) {
                byte[] buffer = new byte[8192];
                int len;
                while ((len = in.read(buffer)) > 0) {
                    out.write(buffer, 0, len);
                }
            }
        }
        String dbName = "Quartermaster4";
        CapacitorSQLite cap = new CapacitorSQLite(context);
        cap.createConnection(dbName, 1);

        long totalStart = android.os.SystemClock.elapsedRealtime();
        cap.open(dbName);
        JSArray tables = cap.query(
            dbName,
            "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%'",
            new JSArray()
        );
        System.out.println("[TEST] tables count=" + tables.length());
        Log.i(TAG, "tables count=" + tables.length());
        for (int i = 0; i < tables.length(); i++) {
            String table = tables.getJSONObject(i).getString("name");
            long tCountStart = android.os.SystemClock.elapsedRealtime();
            JSArray countRows = cap.query(dbName, "SELECT COUNT(*) AS cnt FROM " + table, new JSArray());
            long tCount = android.os.SystemClock.elapsedRealtime() - tCountStart;
            int cnt = countRows.getJSONObject(countRows.length() - 1).getInt("cnt");
            System.out.println("[TEST] table=" + table + " count=" + cnt + " (" + tCount + "ms)");
            Log.i(TAG, "table=" + table + " count=" + cnt + " (" + tCount + "ms)");

            long tSelStart = android.os.SystemClock.elapsedRealtime();
            JSArray allRows = cap.query(dbName, "SELECT * FROM " + table, new JSArray());
            long tSel = android.os.SystemClock.elapsedRealtime() - tSelStart;
            System.out.println("[TEST] table=" + table + " full select rows=" + allRows.length() + " (" + tSel + "ms)");
            Log.i(TAG, "table=" + table + " full select rows=" + allRows.length() + " (" + tSel + "ms)");
        }
        cap.close(dbName);
        cap.closeConnection(dbName);
        long totalElapsed = android.os.SystemClock.elapsedRealtime() - totalStart;
        System.out.println("[TEST] query_all_tables_with_timing total elapsed " + totalElapsed + "ms");
        Log.i(TAG, "query_all_tables_with_timing total elapsed " + totalElapsed + "ms");
        assertTrue("query_all_tables_with_timing exceeded 500ms, elapsed=" + totalElapsed + "ms", totalElapsed <= 500);
    }
}
