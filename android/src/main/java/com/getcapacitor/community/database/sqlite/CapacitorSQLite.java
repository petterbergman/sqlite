package com.getcapacitor.community.database.sqlite;

import android.content.Context;
import com.getcapacitor.JSArray;
import com.getcapacitor.JSObject;
import com.getcapacitor.community.database.sqlite.SQLite.Database;
import com.getcapacitor.community.database.sqlite.SQLite.ImportExportJson.JsonSQLite;
import com.getcapacitor.community.database.sqlite.SQLite.UtilsFile;
import com.getcapacitor.community.database.sqlite.SQLite.UtilsSQLite;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Objects;
import java.util.Set;

public class CapacitorSQLite {

    private final Context context;
    private final Map<String, Database> dbDict = new HashMap<>();
    private final UtilsSQLite uSqlite = new UtilsSQLite();
    private final UtilsFile uFile = new UtilsFile();

    public CapacitorSQLite(Context context) {
        this.context = context;
    }

    /**
     * CreateConnection
     *
     * @param dbName database name
     * @param version database version
     * @throws Exception message
     */
    public void createConnection(String dbName, int version) throws Exception {
        dbName = getDatabaseName(dbName);
        // check if connection already exists
        if (dbDict.containsKey(dbName)) {
            String msg = "Connection " + dbName + " already exists";
            throw new Exception(msg);
        }
        dbDict.put(dbName, new Database(context, dbName + "SQLite.db", version));
    }

    /**
     * Open
     *
     * @param dbName database name
     * @throws Exception message
     */
    public void open(String dbName) throws Exception {
        getConnection(dbName).open();
    }

    /**
     * Close
     *
     * @param dbName database name
     * @throws Exception message
     */
    public void close(String dbName) throws Exception {
        Database db = getConnection(dbName);
        if (!db.isOpen()) {
            throw new Exception("database " + getDatabaseName(dbName) + " not opened");
        }
        if (db.inTransaction()) {
            throw new Exception("database " + getDatabaseName(dbName) + " failed to close still in transaction");
        }
        db.close();
    }

    /**
     * CloseConnection
     *
     * @param dbName database name
     * @throws Exception message
     */
    public void closeConnection(String dbName) throws Exception {
        Database db = getConnection(dbName);
        if (db.isOpen()) {
            db.close();
        }
        dbDict.remove(getDatabaseName(dbName));
    }

    public Boolean checkConnectionsConsistency(JSArray dbNames) throws Exception {
        Set<String> conns = new HashSet<>();
        for (int i = 0; i < dbNames.length(); i++) {
            conns.add(getDatabaseName(dbNames.getString(i)));
        }
        try {
            if (conns.isEmpty() || dbDict.size() < conns.size()) {
                // not solvable inconsistency
                closeAllConnections();
                return false;
            }
            // drop native connections the JS side no longer knows about
            dbDict.keySet().retainAll(conns);
            if (dbDict.keySet().equals(conns)) {
                return true;
            }
            closeAllConnections();
            return false;
        } catch (Exception e) {
            throw new Exception(e.getMessage());
        }
    }

    /**
     * IsDatabase
     *
     * @param dbName database name
     * @return Boolean
     */
    public Boolean isDatabase(String dbName) {
        dbName = getDatabaseName(dbName);
        return uFile.isFileExists(context, dbName + "SQLite.db");
    }

    /**
     * Execute
     *
     * @param dbName Database name
     * @param statements a bench of statement
     * @return JSObject changes
     * @throws Exception message
     */
    public JSObject execute(String dbName, String statements, Boolean transaction) throws Exception {
        Database db = getOpenConnection(dbName);
        // convert string in string[]
        String[] sqlCmdArray = uSqlite.getStatementsArray(statements);
        return db.execute(sqlCmdArray, transaction);
    }

    /**
     * ExecuteSet
     *
     * @param dbName database name
     * @param set Set containing statements and values
     * @return JSObject changes, lastId
     * @throws Exception message
     */
    public JSObject executeSet(String dbName, JSArray set, Boolean transaction) throws Exception {
        return getOpenConnection(dbName).executeSet(set, transaction);
    }

    /**
     * Run
     *
     * @param dbName Database name
     * @param statement SQLite statement
     * @param values SQLite values if any
     * @return JSObject changes, lastId
     * @throws Exception message
     */
    public JSObject run(String dbName, String statement, JSArray values, Boolean transaction) throws Exception {
        Database db = getOpenConnection(dbName);
        ArrayList<Object> arrValues = values.length() > 0 ? uSqlite.objectJSArrayToArrayList(values) : new ArrayList<>();
        return db.runSQL(statement, arrValues, transaction);
    }

    /**
     * Query
     *
     * @param dbName Database name
     * @param statement SQLite statement
     * @param values SQLite values if any
     * @return JSArray
     * @throws Exception message
     */
    public JSArray query(String dbName, String statement, JSArray values) throws Exception {
        Database db = getOpenConnection(dbName);
        ArrayList<Object> arrValues = values.length() > 0 ? uSqlite.objectJSArrayToArrayList(values) : new ArrayList<>();
        return db.selectSQL(statement, arrValues);
    }

    public Boolean isDBOpen(String dbName) throws Exception {
        return getConnection(dbName).isOpen();
    }

    public Boolean isJsonValid(String parsingData) throws Exception {
        try {
            JSObject jsonObject = new JSObject(parsingData);
            JsonSQLite jsonSQL = new JsonSQLite();
            return jsonSQL.isJsonSQLite(jsonObject);
        } catch (Exception e) {
            throw new Exception(e.getMessage());
        }
    }

    public JSObject importFromJson(String parsingData) throws Exception {
        try {
            JSObject jsonObject = new JSObject(parsingData);
            JsonSQLite jsonSQL = new JsonSQLite();
            boolean isValid = jsonSQL.isJsonSQLite(jsonObject);
            if (!isValid) {
                String msg = "Stringify Json Object not Valid";
                throw new Exception(msg);
            }
            String dbName = getDatabaseName(jsonSQL.getDatabase());
            dbName = dbName + "SQLite.db";
            Integer dbVersion = jsonSQL.getVersion();
            Database db = new Database(context, dbName, dbVersion);
            if (jsonSQL.getOverwrite() && this.uFile.isFileExists(context, dbName)) {
                this.uFile.deleteFile(context, dbName);
            }
            db.open();
            // check if the database as some tables
            JSArray tableList = db.getTableNames();
            if (tableList.length() > 0) {
                Integer curVersion = db.getVersion();
                if (dbVersion < curVersion) {
                    db.close();
                    String msg = "ImportFromJson: Cannot import a ";
                    msg += "version lower than" + curVersion;
                    throw new Exception(msg);
                }
                if (curVersion.equals(dbVersion)) {
                    db.close();
                    JSObject result = new JSObject();
                    result.put("changes", Integer.valueOf(0));
                    return result;
                }
            }
            JSObject res = db.importFromJson(jsonSQL);
            db.close();
            if (!Objects.equals(res.getInteger("changes"), -1)) {
                return res;
            } else {
                String msg = "importFromJson: import JsonObject not successful";
                throw new Exception(msg);
            }
        } catch (Exception e) {
            String msg = "importFromJson : " + e.getMessage();
            throw new Exception(msg);
        }
    }

    public JSObject exportToJson(String dbName) throws Exception {
        Database db = getOpenConnection(dbName);
        try {
            JSObject ret = db.exportToJson();
            if (ret.length() == 0) {
                String msg = "ExportToJson: : return Object is empty " + "No data to synchronize";
                throw new Exception(msg);
            }
            return ret;
        } catch (Exception e) {
            String msg = "ExportToJson " + e.getMessage();
            throw new Exception(msg);
        }
    }

    private String getDatabaseName(String dbName) {
        String retName = dbName;
        if (!retName.contains("/")) {
            if (retName.endsWith(".db")) {
                retName = retName.substring(0, retName.length() - 3);
            }
        }
        return retName;
    }

    private Database getConnection(String dbName) throws Exception {
        Database db = dbDict.get(getDatabaseName(dbName));
        if (db == null) {
            String msg = "No available connection for database " + getDatabaseName(dbName);
            throw new Exception(msg);
        }
        return db;
    }

    private Database getOpenConnection(String dbName) throws Exception {
        Database db = getConnection(dbName);
        if (!db.isOpen()) {
            String msg = "database " + getDatabaseName(dbName) + " not opened";
            throw new Exception(msg);
        }
        return db;
    }

    private void closeAllConnections() throws Exception {
        // close all connections
        try {
            for (String dbName : new ArrayList<>(dbDict.keySet())) {
                closeConnection(dbName);
            }
        } catch (Exception e) {
            String msg = "close all connections " + e.getMessage();
            throw new Exception(msg);
        }
    }
}
