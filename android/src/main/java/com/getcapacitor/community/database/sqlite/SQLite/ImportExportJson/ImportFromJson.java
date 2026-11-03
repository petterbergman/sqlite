package com.getcapacitor.community.database.sqlite.SQLite.ImportExportJson;

import androidx.sqlite.db.SupportSQLiteDatabase;
import com.getcapacitor.JSObject;
import com.getcapacitor.community.database.sqlite.SQLite.Database;
import com.getcapacitor.community.database.sqlite.SQLite.UtilsDrop;
import com.getcapacitor.community.database.sqlite.SQLite.UtilsSQLite;
import java.util.ArrayList;
import java.util.Collections;
import org.json.JSONArray;
import org.json.JSONException;

public class ImportFromJson {

    private UtilsJson _uJson = new UtilsJson();
    private UtilsDrop _uDrop = new UtilsDrop();
    private UtilsSQLite _uSqlite = new UtilsSQLite();

    /**
     * Create the database schema for import from Json
     * @param db
     * @param jsonSQL
     * @return
     */
    public Integer createDatabaseSchema(Database db, JsonSQLite jsonSQL) throws Exception {
        // -> update database version
        db.getDb().setVersion(jsonSQL.getVersion());

        try {
            _uDrop.dropAll(db);
            return createSchema(db, jsonSQL);
        } catch (Exception e) {
            String msg = "CreateDatabaseSchema: " + e.getMessage();
            throw new Exception(msg);
        }
    }

    /**
     * Create from the Json Object the database schema
     * @param mDb
     * @param jsonSQL
     * @return
     * @throws Exception
     */
    private Integer createSchema(Database mDb, JsonSQLite jsonSQL) throws Exception {
        int changes = Integer.valueOf(-1);
        SupportSQLiteDatabase db = mDb.getDb();
        // Create a Schema Statement
        ArrayList<String> statements = createSchemaStatement(jsonSQL);
        if (statements.size() == 0) {
            return 0;
        }
        try {
            if (mDb.isOpen()) {
                mDb.beginTransaction();
                Integer initChanges = _uSqlite.dbChanges(db);
                for (String cmd : statements) {
                    db.execSQL(cmd);
                }
                changes = _uSqlite.dbChanges(db) - initChanges;
                if (changes >= 0) {
                    mDb.commitTransaction();
                }
            } else {
                throw new Exception("CreateSchema: Database not opened");
            }
        } catch (Exception e) {
            throw new Exception("CreateSchema: " + e.getMessage());
        } finally {
            if (db != null && db.inTransaction()) mDb.rollbackTransaction();
        }
        return changes;
    }

    /**
     * Create Schema Statements
     * @param jsonSQL
     * @return
     */
    private ArrayList<String> createSchemaStatement(JsonSQLite jsonSQL) {
        ArrayList<String> statements = new ArrayList<>();
        // Loop through Tables
        for (JsonTable table : jsonSQL.getTables()) {
            String tableName = table.getName();
            if (table.getSchema().size() > 0) {
                statements.add(createTableSchema(table.getSchema(), tableName));
            }
            if (table.getIndexes().size() > 0) {
                statements.addAll(createTableIndexes(table.getIndexes(), tableName));
            }
            if (table.getTriggers().size() > 0) {
                statements.addAll(createTableTriggers(table.getTriggers(), tableName));
            }
        }
        return statements;
    }

    /**
     * Create table schema from Json object
     * @param mSchema
     * @param tableName
     * @return
     */
    private String createTableSchema(ArrayList<JsonColumn> mSchema, String tableName) {
        ArrayList<String> definitions = new ArrayList<>();
        for (JsonColumn column : mSchema) {
            if (column.getColumn() != null) {
                definitions.add(column.getColumn() + " " + column.getValue());
            } else if (column.getForeignkey() != null) {
                definitions.add("FOREIGN KEY (" + column.getForeignkey() + ") " + column.getValue());
            } else if (column.getConstraint() != null) {
                definitions.add("CONSTRAINT " + column.getConstraint() + " " + column.getValue());
            }
        }
        return "CREATE TABLE IF NOT EXISTS " + tableName + " (" + String.join(",", definitions) + ");";
    }

    /**
     * Create table indexes from Json object
     * @param mIndexes
     * @param tableName
     * @return
     */
    private ArrayList<String> createTableIndexes(ArrayList<JsonIndex> mIndexes, String tableName) {
        ArrayList<String> statements = new ArrayList<>();
        for (int j = 0; j < mIndexes.size(); j++) {
            String mMode = mIndexes.get(j).getMode();
            String mUnique = mMode.length() > 0 ? mMode + " " : "";
            String stmt = new StringBuilder("CREATE ")
                .append(mUnique)
                .append("INDEX IF NOT EXISTS ")
                .append(mIndexes.get(j).getName())
                .append(" ON ")
                .append(tableName)
                .append(" (")
                .append(mIndexes.get(j).getValue())
                .append(");")
                .toString();
            statements.add(stmt);
        }
        return statements;
    }

    /**
     * Create table triggers from Json object
     * @param mTriggers
     * @param tableName
     * @return
     */
    private ArrayList<String> createTableTriggers(ArrayList<JsonTrigger> mTriggers, String tableName) {
        ArrayList<String> statements = new ArrayList<>();
        for (int j = 0; j < mTriggers.size(); j++) {
            String timeEvent = mTriggers.get(j).getTimeevent();
            if (timeEvent.toUpperCase().endsWith(" ON")) {
                timeEvent = timeEvent.substring(0, timeEvent.length() - 3);
            }

            StringBuilder sBuilder = new StringBuilder("CREATE TRIGGER IF NOT EXISTS ")
                .append(mTriggers.get(j).getName())
                .append(" ")
                .append(timeEvent)
                .append(" ON ")
                .append(tableName)
                .append(" ");
            if (mTriggers.get(j).getCondition() != null) {
                sBuilder.append(mTriggers.get(j).getCondition()).append(" ");
            }
            sBuilder.append(mTriggers.get(j).getLogic());
            String stmt = sBuilder.toString();
            statements.add(stmt);
        }
        return statements;
    }

    /**
     * Create the database tables data for import from Json
     * @param mDb
     * @param jsonSQL
     * @return
     */
    public Integer createDatabaseData(Database mDb, JsonSQLite jsonSQL) throws Exception {
        int changes = Integer.valueOf(-1);
        SupportSQLiteDatabase db = mDb.getDb();
        try {
            if (mDb.isOpen()) {
                int initChanges = _uSqlite.dbChanges(db);
                mDb.beginTransaction();
                for (JsonTable table : jsonSQL.getTables()) {
                    if (table.getValues().size() > 0) {
                        createTableData(mDb, table.getValues(), table.getName());
                    }
                }
                changes = _uSqlite.dbChanges(db) - initChanges;
                if (changes >= 0) {
                    mDb.commitTransaction();
                }
            } else {
                throw new Exception("CreateDatabaseData: Database not opened");
            }
        } catch (Exception e) {
            throw new Exception("CreateDatabaseData: " + e.getMessage());
        } finally {
            if (db != null && db.inTransaction()) mDb.rollbackTransaction();
        }
        return changes;
    }

    /**
     * Insert the table data from the Json Object
     * @param mDb
     * @param values
     * @param tableName
     * @throws Exception
     */
    private void createTableData(Database mDb, ArrayList<ArrayList<Object>> values, String tableName) throws Exception {
        // Check if table exists
        boolean isTable = _uJson.isTableExists(mDb, tableName);
        if (!isTable) {
            throw new Exception("createTableData: Table " + tableName + "does not exist");
        }
        // Get the Column's Names
        JSObject tableNamesTypes = _uJson.getTableColumnNamesTypes(mDb, tableName);
        if (!tableNamesTypes.has("names")) {
            throw new Exception("CreateTableData: Table " + tableName + " no names");
        }
        ArrayList<String> tColNames = _uJson.getColumnNames(tableNamesTypes.get("names"));
        String questionMarks = String.join(",", Collections.nCopies(tColNames.size(), "?"));
        String stmt = "INSERT INTO " + tableName + " (" + String.join(",", tColNames) + ") VALUES (" + questionMarks + ");";
        for (ArrayList<Object> row : values) {
            JSObject retObj = mDb.prepareSQL(stmt, createRowValues(row));
            if (retObj.getLong("lastId") < 0) {
                throw new Exception("CreateTableData: lastId < 0");
            }
        }
    }

    private ArrayList<Object> createRowValues(ArrayList<Object> row) throws JSONException {
        // Replace JSONArray values (BLOBs) by the corresponding byte[]
        for (int i = 0; i < row.size(); i++) {
            Object obj = row.get(i);
            if (obj instanceof JSONArray) {
                JSONArray jsonArrayObj = (JSONArray) obj;
                byte[] byteArray = new byte[jsonArrayObj.length()];
                for (int k = 0; k < jsonArrayObj.length(); k++) {
                    byteArray[k] = (byte) jsonArrayObj.getInt(k);
                }
                row.set(i, byteArray);
            }
        }
        return row;
    }

    /**
     * Create from the Json Object the database views
     * @param mDb
     * @param views
     * @return
     * @throws Exception
     */
    public Integer createViews(Database mDb, ArrayList<JsonView> views) throws Exception {
        int changes = Integer.valueOf(0);
        SupportSQLiteDatabase db = mDb.getDb();
        try {
            if (mDb != null && mDb.isOpen() && views.size() > 0) {
                mDb.beginTransaction();
                // Create Views
                Integer initChanges = _uSqlite.dbChanges(db);
                for (JsonView view : views) {
                    if (view.getName().length() > 0 && view.getValue().length() > 0) {
                        StringBuilder sBuilder = new StringBuilder("CREATE VIEW IF NOT EXISTS ")
                            .append(view.getName())
                            .append(" AS ")
                            .append(view.getValue())
                            .append(" ;");
                        String stmt = sBuilder.toString();
                        db.execSQL(stmt);
                    } else {
                        throw new Exception("CreateViews: no name and value");
                    }
                }
                changes = _uSqlite.dbChanges(db) - initChanges;
                if (changes >= 0) {
                    mDb.commitTransaction();
                }
            } else {
                throw new Exception("CreateViews: Database not opened");
            }
        } catch (Exception e) {
            throw new Exception("CreateViews: " + e.getMessage());
        } finally {
            if (db != null && db.inTransaction()) mDb.rollbackTransaction();
        }
        return changes;
    }
}
