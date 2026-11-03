package com.getcapacitor.community.database.sqlite.SQLite;

import android.database.Cursor;
import android.util.Log;
import java.util.ArrayList;
import java.util.List;

public class UtilsDrop {

    private static final String TAG = UtilsDrop.class.getName();

    /**
     * Get all Table's name
     * @param db
     * @return List<String>
     */

    public List<String> getTablesNames(Database db) throws Exception {
        List<String> tables = new ArrayList<String>();
        Cursor cursor = null;
        String query = "SELECT name FROM sqlite_master WHERE ";
        query += "type='table' AND name NOT LIKE 'sync_table' ";
        query += "AND name NOT LIKE '_temp_%' ";
        query += "AND name NOT LIKE 'sqlite_%' ";
        query += "AND name NOT LIKE 'android_%' ";
        query += "ORDER BY rootpage DESC;";
        try {
            cursor = db.getDb().query(query);
            cursor.moveToFirst();
            while (!cursor.isAfterLast()) {
                String tableName = cursor.getString(0);
                tables.add(tableName);
                cursor.moveToNext();
            }
        } catch (Exception e) {
            throw new Exception("GetTablesNames failed " + e);
        } finally {
            cursor.close();
            return tables;
        }
    }

    /**
     * Get all view's name
     * @param db
     * @return List<String>
     */

    public List<String> getViewNames(Database db) throws Exception {
        List<String> views = new ArrayList<String>();
        Cursor cursor = null;
        String query = "SELECT name FROM sqlite_master WHERE ";
        query += "type='view' AND name NOT LIKE 'sqlite_%' ";
        query += "ORDER BY rootpage DESC;";
        try {
            cursor = db.getDb().query(query);
            cursor.moveToFirst();
            while (!cursor.isAfterLast()) {
                String viewName = cursor.getString(0);
                views.add(viewName);
                cursor.moveToNext();
            }
        } catch (Exception e) {
            throw new Exception("GetTablesNames failed " + e);
        } finally {
            cursor.close();
            return views;
        }
    }

    /**
     * Drop all Tables
     * @param db
     */
    public void dropTables(Database db) throws Exception {
        try {
            List<String> tables = getTablesNames(db);
            for (String tableName : tables) {
                db.getDb().execSQL("DROP TABLE IF EXISTS " + tableName + " ;");
            }
        } catch (Exception e) {
            String msg = "DropAllTables failed: " + e;
            Log.d(TAG, msg);
            throw new Exception(msg);
        }
    }

    /**
     * Drop all Views
     * @param db
     */
    public void dropViews(Database db) throws Exception {
        try {
            List<String> views = getViewNames(db);
            for (String viewName : views) {
                db.getDb().execSQL("DROP VIEW IF EXISTS " + viewName + " ;");
            }
        } catch (Exception e) {
            String msg = "DropAllViews failed: " + e;
            Log.d(TAG, msg);
            throw new Exception(msg);
        }
    }

    /**
     * get all index's name
     * @param db
     * @return List<String>
     */

    public List<String> getIndexesNames(Database db) {
        List<String> indexes = new ArrayList<String>();
        Cursor cursor = null;
        String query = "SELECT name FROM sqlite_master WHERE ";
        query += "type='index' AND name NOT LIKE 'sqlite_%';";
        cursor = db.getDb().query(query);
        cursor.moveToFirst();
        while (!cursor.isAfterLast()) {
            String indexName = cursor.getString(0);
            indexes.add(indexName);
            cursor.moveToNext();
        }
        cursor.close();
        return indexes;
    }

    /**
     * Drop all Indexes
     * @param db
     */
    public void dropIndexes(Database db) throws Exception {
        List<String> indexes = getIndexesNames(db);
        try {
            for (String indexName : indexes) {
                db.getDb().execSQL("DROP INDEX IF EXISTS " + indexName);
            }
        } catch (Exception e) {
            String msg = "DropAllIndexes failed: " + e;
            Log.d(TAG, msg);
            throw new Exception(msg);
        }
    }

    /**
     * get all trigger's name
     * @param db
     * @return List<String>
     */

    public List<String> getTriggersNames(Database db) {
        List<String> triggers = new ArrayList<String>();
        Cursor cursor = null;
        String query = "SELECT name FROM sqlite_master WHERE ";
        query += "type='trigger';";
        cursor = db.getDb().query(query);
        cursor.moveToFirst();
        while (!cursor.isAfterLast()) {
            String triggerName = cursor.getString(0);
            triggers.add(triggerName);
            cursor.moveToNext();
        }
        cursor.close();
        return triggers;
    }

    /**
     * Drop all Triggers
     * @param db
     */
    public void dropTriggers(Database db) throws Exception {
        List<String> triggers = getTriggersNames(db);
        try {
            for (String triggerName : triggers) {
                db.getDb().execSQL("DROP TRIGGER IF EXISTS " + triggerName);
            }
        } catch (Exception e) {
            String msg = "DropAllTriggers failed: " + e;
            Log.d(TAG, msg);
            throw new Exception(msg);
        }
    }

    /**
     * Drop all
     * @param db
     */
    public void dropAll(Database db) throws Exception {
        Boolean success = false;
        try {
            db.beginTransaction();
            dropTables(db);
            dropIndexes(db);
            dropTriggers(db);
            dropViews(db);
            db.commitTransaction();
            success = true;
        } catch (Exception e) {
            String msg = "DropAll failed: " + e;
            Log.d(TAG, msg);
            throw new Exception(msg);
        } finally {
            if (success) db.rollbackTransaction();
            try {
                db.getDb().execSQL("VACUUM;");
            } catch (Exception e) {
                String msg = "DropAll VACUUM failed: " + e;
                Log.d(TAG, msg);
                throw new Exception(msg);
            }
        }
    }
}
