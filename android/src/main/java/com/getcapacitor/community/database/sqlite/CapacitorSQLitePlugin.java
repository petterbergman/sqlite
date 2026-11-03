package com.getcapacitor.community.database.sqlite;

import android.content.Context;
import android.util.Log;
import com.getcapacitor.JSArray;
import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import org.json.JSONArray;

@CapacitorPlugin(name = "CapacitorSQLite")
public class CapacitorSQLitePlugin extends Plugin {

    private static final String TAG = CapacitorSQLitePlugin.class.getName();
    private CapacitorSQLite implementation;
    private final RetHandler rHandler = new RetHandler();
    private String loadMessage = "";

    /**
     * Load Method
     * Load the context
     */
    public void load() {
        Context context = getContext();
        try {
            implementation = new CapacitorSQLite(context);
        } catch (Exception e) {
            implementation = null;
            loadMessage = "CapacitorSQLitePlugin: " + e.getMessage();
            Log.e(TAG, loadMessage);
        }
    }

    /**
     * CreateConnection Method
     * Create a connection to a database
     *
     * @param call PluginCall
     */
    @PluginMethod
    public void createConnection(PluginCall call) {
        if (!call.getData().has("database")) {
            String msg = "CreateConnection: Must provide a database name";
            rHandler.retResult(call, null, msg);
            return;
        }
        String dbName = call.getString("database");
        int dbVersion = call.getInt("version", 1);
        if (implementation != null) {
            try {
                implementation.createConnection(dbName, dbVersion);
                rHandler.retResult(call, null, null);
            } catch (Exception e) {
                String msg = "CreateConnection: " + e.getMessage();
                rHandler.retResult(call, null, msg);
            }
        } else {
            rHandler.retResult(call, null, loadMessage);
        }
    }

    /**
     * Open Method
     * Open a database
     *
     * @param call PluginCall
     */
    @PluginMethod
    public void open(PluginCall call) {
        if (!call.getData().has("database")) {
            String msg = "Open: Must provide a database name";
            rHandler.retResult(call, null, msg);
            return;
        }
        String dbName = call.getString("database");
        if (implementation != null) {
            try {
                implementation.open(dbName);
                rHandler.retResult(call, null, null);
            } catch (Exception e) {
                String msg = "Open: " + e.getMessage();
                rHandler.retResult(call, null, msg);
            }
        } else {
            rHandler.retResult(call, null, loadMessage);
        }
    }

    /**
     * Close Method
     * Close a Database
     *
     * @param call PluginCall
     */
    @PluginMethod
    public void close(PluginCall call) {
        if (!call.getData().has("database")) {
            String msg = "Close: Must provide a database name";
            rHandler.retResult(call, null, msg);
            return;
        }
        String dbName = call.getString("database");
        if (implementation != null) {
            try {
                implementation.close(dbName);
                rHandler.retResult(call, null, null);
            } catch (Exception e) {
                String msg = "Close: " + e.getMessage();
                rHandler.retResult(call, null, msg);
            }
        } else {
            rHandler.retResult(call, null, loadMessage);
        }
    }

    /**
     * CloseConnection Method
     * Close the connection to a database
     *
     * @param call PluginCall
     */
    @PluginMethod
    public void closeConnection(PluginCall call) {
        if (!call.getData().has("database")) {
            String msg = "CloseConnection: Must provide a database name";
            rHandler.retResult(call, null, msg);
            return;
        }
        String dbName = call.getString("database");
        if (implementation != null) {
            try {
                implementation.closeConnection(dbName);
                rHandler.retResult(call, null, null);
            } catch (Exception e) {
                String msg = "CloseConnection: " + e.getMessage();
                rHandler.retResult(call, null, msg);
            }
        } else {
            rHandler.retResult(call, null, loadMessage);
        }
    }

    /**
     * CheckConnectionsConsistency Method
     * Check the connections consistency JS <=> Native
     * if inconsistency all connections are removed
     *
     * @param call PluginCall
     */
    @PluginMethod
    public void checkConnectionsConsistency(PluginCall call) {
        JSArray dbNames = call.getArray("dbNames");
        if (dbNames == null) {
            String msg = "CheckConnectionsConsistency: Must provide a " + "connection Array";
            rHandler.retResult(call, null, msg);
            return;
        }
        if (implementation != null) {
            try {
                Boolean res = implementation.checkConnectionsConsistency(dbNames);
                rHandler.retResult(call, res, null);
            } catch (Exception e) {
                String msg = "CheckConnectionsConsistency: " + e.getMessage();
                rHandler.retResult(call, null, msg);
            }
        } else {
            rHandler.retResult(call, null, loadMessage);
        }
    }

    /**
     * IsDatabase Method
     * Check if the database file exists
     *
     * @param call PluginCall
     */
    @PluginMethod
    public void isDatabase(PluginCall call) {
        if (!call.getData().has("database")) {
            rHandler.retResult(call, null, "Must provide a database name");
            return;
        }
        String dbName = call.getString("database");
        if (implementation != null) {
            try {
                Boolean res = implementation.isDatabase(dbName);
                rHandler.retResult(call, res, null);
            } catch (Exception e) {
                String msg = "isDatabase: " + e.getMessage();
                rHandler.retResult(call, null, msg);
            }
        } else {
            rHandler.retResult(call, null, loadMessage);
        }
    }

    /**
     * Execute Method
     * Execute SQL statements provided in a String
     *
     * @param call PluginCall
     */
    @PluginMethod
    public void execute(PluginCall call) {
        JSObject retRes = new JSObject();
        retRes.put("changes", Integer.valueOf(-1));
        if (!call.getData().has("database")) {
            String msg = "Execute: Must provide a database name";
            rHandler.retChanges(call, retRes, msg);
            return;
        }
        String dbName = call.getString("database");
        if (!call.getData().has("statements")) {
            String msg = "Execute: Must provide raw SQL statements";
            rHandler.retChanges(call, retRes, msg);
            return;
        }
        String statements = call.getString("statements");
        Boolean transaction = call.getBoolean("transaction", true);
        if (implementation != null) {
            try {
                JSObject res = implementation.execute(dbName, statements, transaction);
                rHandler.retChanges(call, res, null);
            } catch (Exception e) {
                String msg = "Execute: " + e.getMessage();
                rHandler.retChanges(call, retRes, msg);
            }
        } else {
            rHandler.retChanges(call, retRes, loadMessage);
        }
    }

    /**
     * ExecuteSet Method
     * Execute a Set of raw sql statement
     *
     * @param call PluginCall
     * @throws Exception message
     */
    @PluginMethod
    public void executeSet(PluginCall call) throws Exception {
        JSObject retRes = new JSObject();
        retRes.put("changes", Integer.valueOf(-1));
        if (!call.getData().has("database")) {
            String msg = "ExecuteSet: Must provide a database name";
            rHandler.retChanges(call, retRes, msg);
            return;
        }
        String dbName = call.getString("database");
        JSArray set = call.getArray("set");
        if (set == null) {
            String msg = "ExecuteSet: Must provide a set of SQL statements";
            rHandler.retChanges(call, retRes, msg);
            return;
        }
        if (set.length() == 0) {
            String msg = "ExecuteSet: Must provide a non-empty set of SQL statements";
            rHandler.retChanges(call, retRes, msg);
            return;
        }
        for (int i = 0; i < set.length(); i++) {
            JSONArray keys = set.getJSONObject(i).names();
            for (int j = 0; j < keys.length(); ++j) {
                String key = keys.getString(j);
                if (!(key.equals("statement")) && !(key.equals("values"))) {
                    String msg = "ExecuteSet: Must provide a set as Array of {statement,";
                    msg += "values}";
                    rHandler.retChanges(call, retRes, msg);
                    return;
                }
            }
        }
        Boolean transaction = call.getBoolean("transaction", true);
        if (implementation != null) {
            try {
                JSObject res = implementation.executeSet(dbName, set, transaction);
                rHandler.retChanges(call, res, null);
            } catch (Exception e) {
                String msg = "ExecuteSet: " + e.getMessage();
                rHandler.retChanges(call, retRes, msg);
            }
        } else {
            rHandler.retChanges(call, retRes, loadMessage);
        }
    }

    /**
     * Run method
     * Execute a raw sql statement
     *
     * @param call PluginCall
     */
    @PluginMethod
    public void run(PluginCall call) {
        JSObject retRes = new JSObject();
        retRes.put("changes", Integer.valueOf(-1));
        if (!call.getData().has("database")) {
            String msg = "Run: Must provide a database name";
            rHandler.retChanges(call, retRes, msg);
            return;
        }
        String dbName = call.getString("database");
        if (!call.getData().has("statement")) {
            String msg = "Run: Must provide a SQL statement";
            rHandler.retChanges(call, retRes, msg);
            return;
        }
        String statement = call.getString("statement");
        JSArray values = call.getArray("values");
        if (values == null) {
            String msg = "Run: Must provide an Array of values";
            rHandler.retChanges(call, retRes, msg);
            return;
        }
        Boolean transaction = call.getBoolean("transaction", true);
        if (implementation != null) {
            try {
                JSObject res = implementation.run(dbName, statement, values, transaction);
                rHandler.retChanges(call, res, null);
            } catch (Exception e) {
                String msg = "Run: " + e.getMessage();
                rHandler.retChanges(call, retRes, msg);
            }
        } else {
            rHandler.retChanges(call, retRes, loadMessage);
        }
    }

    /**
     * Query Method
     * Execute an sql query
     *
     * @param call PluginCall
     */
    @PluginMethod
    public void query(PluginCall call) {
        if (!call.getData().has("database")) {
            String msg = "Query: Must provide a database name";
            rHandler.retValues(call, new JSArray(), msg);
            return;
        }
        String dbName = call.getString("database");
        if (!call.getData().has("statement")) {
            String msg = "Query: Must provide a SQL statement";
            rHandler.retValues(call, new JSArray(), msg);
            return;
        }
        String statement = call.getString("statement");
        JSArray values = call.getArray("values");
        if (values == null) {
            String msg = "Query: Must provide an Array of values";
            rHandler.retValues(call, new JSArray(), msg);
            return;
        }
        if (implementation != null) {
            try {
                JSArray res = implementation.query(dbName, statement, values);
                rHandler.retValues(call, res, null);
            } catch (Exception e) {
                String msg = "Query: " + e.getMessage();
                rHandler.retValues(call, new JSArray(), msg);
            }
        } else {
            rHandler.retValues(call, new JSArray(), loadMessage);
        }
    }

    /**
     * IsDBOpen Method
     * check if the database is opened
     *
     * @param call PluginCall
     */
    @PluginMethod
    public void isDBOpen(PluginCall call) {
        if (!call.getData().has("database")) {
            String msg = "isDBOpen: Must provide a database name";
            rHandler.retResult(call, false, msg);
            return;
        }
        String dbName = call.getString("database");
        if (implementation != null) {
            try {
                Boolean res = implementation.isDBOpen(dbName);
                rHandler.retResult(call, res, null);
            } catch (Exception e) {
                String msg = "isDBOpen: " + e.getMessage();
                rHandler.retResult(call, false, msg);
            }
        } else {
            rHandler.retResult(call, null, loadMessage);
        }
    }

    /**
     * IsJsonValid
     * Check the validity of a given Json object
     *
     * @param call PluginCall
     */
    @PluginMethod
    public void isJsonValid(PluginCall call) {
        if (!call.getData().has("jsonstring")) {
            String msg = "IsJsonValid: Must provide a Stringify Json Object";
            rHandler.retResult(call, false, msg);
            return;
        }
        String parsingData = call.getString("jsonstring");
        if (implementation != null) {
            try {
                Boolean res = implementation.isJsonValid(parsingData);
                rHandler.retResult(call, res, null);
            } catch (Exception e) {
                String msg = "IsJsonValid: " + e.getMessage();
                rHandler.retResult(call, false, msg);
            }
        } else {
            rHandler.retResult(call, null, loadMessage);
        }
    }

    /**
     * ImportFromJson Method
     * Import from a given Json object
     *
     * @param call PluginCall
     */
    @PluginMethod
    public void importFromJson(PluginCall call) {
        JSObject retRes = new JSObject();
        retRes.put("changes", Integer.valueOf(-1));
        if (!call.getData().has("jsonstring")) {
            String msg = "ImportFromJson: Must provide a Stringify Json Object";
            rHandler.retChanges(call, retRes, msg);
            return;
        }
        String parsingData = call.getString("jsonstring");
        if (implementation != null) {
            try {
                JSObject res = implementation.importFromJson(parsingData);
                rHandler.retChanges(call, res, null);
            } catch (Exception e) {
                String msg = "ImportFromJson: " + e.getMessage();
                rHandler.retChanges(call, retRes, msg);
            }
        } else {
            rHandler.retChanges(call, retRes, loadMessage);
        }
    }

    /**
     * ExportToJson Method
     * Export the whole database to a Json Object
     *
     * @param call PluginCall
     */
    @PluginMethod
    public void exportToJson(PluginCall call) {
        JSObject retObj = new JSObject();
        if (!call.getData().has("database")) {
            String msg = "ExportToJson: Must provide a database name";
            rHandler.retJSObject(call, retObj, msg);
            return;
        }
        String dbName = call.getString("database");
        if (implementation != null) {
            try {
                JSObject res = implementation.exportToJson(dbName);
                rHandler.retJSObject(call, res, null);
            } catch (Exception e) {
                String msg = "ExportToJson: " + e.getMessage();
                rHandler.retJSObject(call, retObj, msg);
            }
        } else {
            rHandler.retJSObject(call, retObj, loadMessage);
        }
    }
}
