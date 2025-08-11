package com.getcapacitor.community.database.sqlite;

import static org.junit.Assert.*;

import android.content.Context;

import androidx.test.ext.junit.runners.AndroidJUnit4;
import androidx.test.platform.app.InstrumentationRegistry;

import com.getcapacitor.JSArray;
import com.getcapacitor.JSObject;
import com.getcapacitor.community.database.sqlite.SQLite.Database;
import com.getcapacitor.community.database.sqlite.SQLite.SqliteConfig;

import org.json.JSONObject;
import org.junit.Test;
import org.junit.runner.RunWith;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.Hashtable;

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

        // Place basic.json into android/app/src/main/assets/ or this module's assets via test APK assets merging
        String json = loadJsonFromAssets(context, "basic.json");
        assertTrue(json.contains("testjson_file"));

        CapacitorSQLite cap = new CapacitorSQLite(context, new SqliteConfig());
        // Validate JSON
        assertTrue(cap.isJsonValid(json));

        // Import
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
    }
}
