package com.getcapacitor.community.database.sqlite.SQLite;

import static android.database.Cursor.FIELD_TYPE_BLOB;
import static android.database.Cursor.FIELD_TYPE_FLOAT;
import static android.database.Cursor.FIELD_TYPE_INTEGER;
import static android.database.Cursor.FIELD_TYPE_NULL;
import static android.database.Cursor.FIELD_TYPE_STRING;

import android.content.Context;
import android.database.Cursor;
import android.util.Log;
import androidx.sqlite.db.SimpleSQLiteQuery;
import androidx.sqlite.db.SupportSQLiteDatabase;
import androidx.sqlite.db.SupportSQLiteOpenHelper;
import androidx.sqlite.db.SupportSQLiteStatement;
import androidx.sqlite.db.framework.FrameworkSQLiteOpenHelperFactory;
import com.getcapacitor.JSArray;
import com.getcapacitor.JSObject;
import com.getcapacitor.community.database.sqlite.SQLite.ImportExportJson.ExportToJson;
import com.getcapacitor.community.database.sqlite.SQLite.ImportExportJson.ImportFromJson;
import com.getcapacitor.community.database.sqlite.SQLite.ImportExportJson.JsonSQLite;
import java.io.File;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import org.json.JSONArray;
import org.json.JSONObject;

public class Database {

    private static final String TAG = Database.class.getName();
    private Boolean _isOpen = false;
    private final String _dbName;
    private final Context _context;
    private final File _file;
    private final int _version;
    private SupportSQLiteDatabase _db = null;
    private final UtilsSQLite _uSqlite;
    private final UtilsDrop _uDrop;
    private final ImportFromJson fromJson = new ImportFromJson();
    private final ExportToJson toJson = new ExportToJson();

    public Database(Context context, String dbName, int version) {
        this._context = context;
        this._dbName = dbName;
        this._version = version;
        this._file = this._context.getDatabasePath(dbName);
        this._uSqlite = new UtilsSQLite();
        this._uDrop = new UtilsDrop();
        if (!Objects.requireNonNull(this._file.getParentFile()).exists()) {
            boolean dirCreated = this._file.getParentFile().mkdirs();
            if (!dirCreated) {
                System.out.println("Failed to create parent directories.");
            }
        }
        Log.v(TAG, "&&& file path " + this._file.getAbsolutePath());
    }

    public SupportSQLiteDatabase getDb() {
        return _db;
    }

    /**
     * isOpen Method
     *
     * @return database status
     */
    public Boolean isOpen() {
        return _isOpen;
    }

    /**
     * BeginTransaction method
     *
     * @return begin a database transaction
     */
    public Integer beginTransaction() throws Exception {
        if (_db.isOpen()) {
            try {
                if (_db.inTransaction()) {
                    throw new Exception("Already in transaction");
                }
                _db.beginTransaction();
                return 0;
            } catch (Exception e) {
                String msg = "Failed in beginTransaction" + e.getMessage();
                Log.v(TAG, msg);
                throw new Exception(msg);
            }
        } else {
            throw new Exception("Database not opened");
        }
    }

    /**
     * CommitTransaction method
     *
     * @return commit a database transaction
     */
    public Integer commitTransaction() throws Exception {
        if (_db.isOpen()) {
            try {
                if (!_db.inTransaction()) {
                    throw new Exception("No transaction active");
                }
                _db.setTransactionSuccessful();
                return 0;
            } catch (Exception e) {
                String msg = "Failed in commitTransaction" + e.getMessage();
                Log.v(TAG, msg);
                throw new Exception(msg);
            } finally {
                _db.endTransaction();
            }
        } else {
            throw new Exception("Database not opened");
        }
    }

    /**
     * Rollback Transaction method
     *
     * @return rollback a database transaction
     */
    public Integer rollbackTransaction() throws Exception {
        if (_db.isOpen()) {
            try {
                if (_db.inTransaction()) {
                    _db.endTransaction();
                }
                return 0;
            } catch (Exception e) {
                String msg = "Failed in rollbackTransaction" + e.getMessage();
                Log.v(TAG, msg);
                throw new Exception(msg);
            }
        } else {
            throw new Exception("Database not opened");
        }
    }

    /**
     * Open method
     *
     * @return open status
     */
    public void open() throws Exception {
        try {
            SupportSQLiteOpenHelper.Configuration cfg = SupportSQLiteOpenHelper.Configuration.builder(_context)
                .name(_dbName)
                .callback(
                    new SupportSQLiteOpenHelper.Callback(_version) {
                        @Override
                        public void onCreate(SupportSQLiteDatabase db) {}

                        @Override
                        public void onUpgrade(SupportSQLiteDatabase db, int oldVersion, int newVersion) {}
                    }
                )
                .build();
            SupportSQLiteOpenHelper helper = new FrameworkSQLiteOpenHelperFactory().create(cfg);
            _db = helper.getWritableDatabase();
            if (_db != null) {
                if (_db.isOpen()) {
                    // set the Foreign Key Pragma ON
                    try {
                        _db.setForeignKeyConstraintsEnabled(true);
                    } catch (IllegalStateException e) {
                        String msg = "Failed in setForeignKeyConstraintsEnabled " + e.getMessage();
                        Log.v(TAG, msg);
                        close();
                        _db = null;
                        throw new Exception(msg);
                    }
                    _isOpen = true;
                } else {
                    _isOpen = false;
                    _db = null;
                    throw new Exception("Database not opened");
                }
            } else {
                _isOpen = false;
                _db = null;
                throw new Exception("No database returned");
            }
        } catch (Exception e) {
            String msg = "Error in creating the database" + e.getMessage();
            _isOpen = false;
            _db = null;
            throw new Exception(msg);
        }
    }

    /**
     * Close Method
     *
     * @return close status
     */

    public void close() throws Exception {
        if (_db.isOpen()) {
            try {
                _db.close();
                _isOpen = false;
                return;
            } catch (Exception e) {
                String msg = "Failed in database close" + e.getMessage();
                Log.v(TAG, msg);
                throw new Exception(msg);
            }
        } else {
            throw new Exception("Database not opened");
        }
    }

    public Integer getVersion() throws Exception {
        if (_db.isOpen()) {
            try {
                Integer curVersion = _db.getVersion();
                return curVersion;
            } catch (Exception e) {
                String msg = "Failed in database getVersion" + e.getMessage();
                Log.v(TAG, msg);
                throw new Exception(msg);
            }
        } else {
            throw new Exception("Database not opened");
        }
    }

    /**
     * Execute Method
     * Execute an Array of SQL Statements
     *
     * @param statements Array of Strings
     * @return
     */
    public JSObject execute(String[] statements, Boolean transaction) throws Exception {
        JSObject retObj = new JSObject();
        Integer changes = Integer.valueOf(-1);
        try {
            if (_db != null && _db.isOpen()) {
                Integer initChanges = _uSqlite.dbChanges(_db);
                if (transaction) beginTransaction();
                for (String cmd : statements) {
                    if (!cmd.endsWith(";")) cmd += ";";
                    _db.execSQL(cmd);
                }
                changes = _uSqlite.dbChanges(_db) - initChanges;
                if (changes != -1) {
                    if (transaction) commitTransaction();
                    retObj.put("changes", changes);
                }
                return retObj;
            } else {
                throw new Exception("Database not opened");
            }
        } catch (Exception e) {
            throw new Exception(e.getMessage());
        } finally {
            if (_db != null && transaction && _db.inTransaction()) rollbackTransaction();
        }
    }

    /**
     * ExecuteSet Method
     * Execute a Set of SQL Statements
     *
     * @param set JSArray of statements
     * @return
     */
    public JSObject executeSet(JSArray set, Boolean transaction) throws Exception {
        JSObject retObj = new JSObject();
        Long lastId = (long) -1;
        Integer changes = -1;
        try {
            if (_db != null && _db.isOpen()) {
                int initChanges = _uSqlite.dbChanges(_db);
                if (transaction) beginTransaction();
                for (int i = 0; i < set.length(); i++) {
                    JSONObject row = set.getJSONObject(i);
                    String statement = row.getString("statement");
                    JSONArray valuesJson = row.getJSONArray("values");
                    ArrayList<Object> values = new ArrayList<>();
                    for (int j = 0; j < valuesJson.length(); j++) {
                        values.add(valuesJson.get(j));
                    }
                    lastId = prepareSQL(statement, values).getLong("lastId");
                    if (lastId.equals(-1L)) break;
                }
                if (lastId.equals(-1L)) {
                    throw new Exception("lastId equals -1");
                } else {
                    if (transaction) commitTransaction();
                    changes = _uSqlite.dbChanges(_db) - initChanges;
                    retObj.put("changes", changes);
                    retObj.put("lastId", lastId);
                    return retObj;
                }
            } else {
                throw new Exception("Database not opened");
            }
        } catch (Exception e) {
            throw new Exception(e.getMessage());
        } finally {
            if (_db != null && transaction && _db.inTransaction()) rollbackTransaction();
        }
    }

    /**
     * InTransaction Method
     * Check if a transaction is still running
     *
     * @return
     */
    public boolean inTransaction() {
        return _db.inTransaction();
    }

    /**
     * RunSQL Method
     *
     * @param statement a raw SQL statement
     * @param values    Array of Strings to bind to the statement
     * @return
     */
    public JSObject runSQL(String statement, ArrayList<Object> values, Boolean transaction) throws Exception {
        JSObject retObj = new JSObject();
        long lastId = (long) -1;
        int changes = -1;
        try {
            if (_db != null && _db.isOpen() && statement.length() > 0) {
                int initChanges = _uSqlite.dbChanges(_db);
                if (transaction) beginTransaction();
                lastId = prepareSQL(statement, values).getLong("lastId");
                if (lastId != -1 && transaction) commitTransaction();
                changes = _uSqlite.dbChanges(_db) - initChanges;
                retObj.put("changes", changes);
                retObj.put("lastId", lastId);
                return retObj;
            } else {
                throw new Exception("Database not opened");
            }
        } catch (Exception e) {
            throw new Exception(e.getMessage());
        } finally {
            if (_db != null && transaction && _db.inTransaction()) rollbackTransaction();
        }
    }

    /**
     * PrepareSQL Method
     *
     * @param statement SQL statement
     * @param values SQL Values if any
     * @return JSObject with the lastId
     * @throws Exception message
     */
    public JSObject prepareSQL(String statement, ArrayList<Object> values) throws Exception {
        String stmtType = statement.trim().split("\\s+")[0].toUpperCase();
        SupportSQLiteStatement stmt = null;
        JSObject retObject = new JSObject();
        try {
            stmt = _db.compileStatement(statement);
            if (values != null && values.size() > 0) {
                Object[] valObj = new Object[values.size()];
                for (int i = 0; i < values.size(); i++) {
                    if (values.get(i) == null) {
                        valObj[i] = null;
                    } else if (JSONObject.NULL == values.get(i)) {
                        valObj[i] = null;
                    } else {
                        valObj[i] = values.get(i);
                    }
                }
                SimpleSQLiteQuery.bind(stmt, valObj);
            }
            if (stmtType.equals("INSERT")) {
                stmt.executeInsert();
            } else {
                stmt.executeUpdateDelete();
            }
            retObject.put("lastId", _uSqlite.dbLastId(_db));
            return retObject;
        } catch (Exception e) {
            throw new Exception(e.getMessage());
        } finally {
            if (stmt != null) {
                stmt.close();
            }
        }
    }

    /**
     * SelectSQL Method
     * Query a raw sql statement with or without binding values
     *
     * @param statement
     * @param values
     * @return
     */
    public JSArray selectSQL(String statement, ArrayList<Object> values) throws Exception {
        JSArray retArray = new JSArray();
        Cursor c = null;
        if (_db == null) {
            return retArray;
        }
        try {
            c = _db.query(statement, values.toArray(new Object[0]));
            while (c.moveToNext()) {
                JSObject row = new JSObject();
                for (int i = 0; i < c.getColumnCount(); i++) {
                    String colName = c.getColumnName(i);
                    int index = c.getColumnIndex(colName);
                    int type = c.getType(i);
                    switch (type) {
                        case FIELD_TYPE_STRING:
                            row.put(colName, c.getString(index));
                            break;
                        case FIELD_TYPE_INTEGER:
                            row.put(colName, c.getLong(index));
                            break;
                        case FIELD_TYPE_FLOAT:
                            row.put(colName, c.getDouble(index));
                            break;
                        case FIELD_TYPE_BLOB:
                            byte[] blobVal = c.getBlob(index);
                            JSArray arr = this._uSqlite.ByteArrayToJSArray(blobVal);
                            row.put(colName, arr);
                            break;
                        case FIELD_TYPE_NULL:
                            row.put(colName, JSONObject.NULL);
                            break;
                        default:
                            break;
                    }
                }
                retArray.put(row);
            }
            return retArray;
        } catch (Exception e) {
            throw new Exception("in selectSQL cursor " + e.getMessage());
        } finally {
            if (c != null) c.close();
        }
    }

    /**
     * GetTableNames Method
     * Returned a JSArray of table's name
     *
     * @return
     * @throws Exception
     */
    public JSArray getTableNames() throws Exception {
        JSArray retArray = new JSArray();
        try {
            List<String> tableList = this._uDrop.getTablesNames(this);
            for (int i = 0; i < tableList.size(); i++) {
                retArray.put(tableList.get(i));
            }
            return retArray;
        } catch (Exception e) {
            throw new Exception("in getTableNames " + e.getMessage());
        }
    }

    /**
     * Import from Json object
     *
     * @param jsonSQL
     * @return
     */
    public JSObject importFromJson(JsonSQLite jsonSQL) throws Exception {
        JSObject retObj = new JSObject();
        int changes = Integer.valueOf(0);
        try {
            // set Foreign Keys OFF
            _db.setForeignKeyConstraintsEnabled(false);

            if (jsonSQL.getTables().size() > 0) {
                // create the database schema
                changes = fromJson.createDatabaseSchema(this, jsonSQL);
                if (changes != -1) {
                    changes += fromJson.createDatabaseData(this, jsonSQL);
                }
            }
            if (jsonSQL.getViews().size() > 0) {
                changes += fromJson.createViews(this, jsonSQL.getViews());
            }
            // set Foreign Keys ON
            _db.setForeignKeyConstraintsEnabled(true);

            retObj.put("changes", changes);
            return retObj;
        } catch (Exception e) {
            throw new Exception(e.getMessage());
        }
    }

    /**
     * Export the whole database to a JSON Object
     *
     * @return
     */
    public JSObject exportToJson() throws Exception {
        JsonSQLite inJson = new JsonSQLite();
        JSObject retObj = new JSObject();
        inJson.setDatabase(_dbName.substring(0, _dbName.length() - 9));
        inJson.setVersion(_version);
        try {
            JsonSQLite retJson = toJson.createExportObject(this, inJson);
            if (retJson.getTables().size() > 0) {
                retObj.put("database", retJson.getDatabase());
                retObj.put("version", retJson.getVersion());
                retObj.put("tables", retJson.getTablesAsJSObject());
                if (retJson.getViews().size() > 0) {
                    retObj.put("views", retJson.getViewsAsJSObject());
                }
            }
            return retObj;
        } catch (Exception e) {
            Log.e(TAG, "Error: exportToJson " + e.getMessage());
            throw new Exception(e.getMessage());
        }
    }
}
