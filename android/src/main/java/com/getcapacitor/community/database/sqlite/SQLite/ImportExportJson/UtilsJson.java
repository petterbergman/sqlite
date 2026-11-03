package com.getcapacitor.community.database.sqlite.SQLite.ImportExportJson;

import com.getcapacitor.JSArray;
import com.getcapacitor.JSObject;
import com.getcapacitor.community.database.sqlite.SQLite.Database;
import java.util.ArrayList;
import java.util.List;
import org.json.JSONException;
import org.json.JSONObject;

public class UtilsJson {

    private JsonColumn uJCol = new JsonColumn();
    private JsonIndex uJIdx = new JsonIndex();
    private JsonTrigger uJTrg = new JsonTrigger();

    /**
     * Get Column name's list
     * @param obj
     * @return
     */
    @SuppressWarnings("unchecked")
    public ArrayList<String> getColumnNames(Object obj) {
        ArrayList<String> colNames = new ArrayList<>();
        if (obj instanceof ArrayList) colNames = (ArrayList<String>) obj;

        return colNames;
    }

    /**
     * Check if a table exists
     *
     * @param db
     * @param tableName
     * @return
     */
    public boolean isTableExists(Database db, String tableName) throws Exception {
        boolean ret = false;
        String query = new StringBuilder("SELECT name FROM " + "sqlite_master WHERE type='table' AND name='")
            .append(tableName)
            .append("';")
            .toString();
        try {
            JSArray resQuery = db.selectSQL(query, new ArrayList<Object>());
            if (resQuery.length() > 0) ret = true;
            return ret;
        } catch (Exception e) {
            throw new Exception("isTableExists: " + e.getMessage());
        }
    }

    /**
     * Create a String from a given Array of Strings with
     * a given separator
     *
     * @param arr
     * @param sep
     * @return
     */

    /**
     * Get Field's type and name for a given table
     *
     * @param mDb
     * @param tableName
     * @return
     * @throws JSONException
     */
    public JSObject getTableColumnNamesTypes(Database mDb, String tableName) throws Exception {
        JSObject ret = new JSObject();
        ArrayList<String> names = new ArrayList<String>();
        ArrayList<String> types = new ArrayList<String>();
        String query = new StringBuilder("PRAGMA table_info('").append(tableName).append("');").toString();
        try {
            JSArray resQuery = mDb.selectSQL(query, new ArrayList<Object>());
            List<JSObject> lQuery = resQuery.toList();
            if (lQuery.size() > 0) {
                for (JSObject obj : lQuery) {
                    names.add(obj.getString("name"));
                    types.add(obj.getString("type"));
                }
                ret.put("names", names);
                ret.put("types", types);
            }
            return ret;
        } catch (JSONException e) {
            throw new Exception("GetTableColumnNamesTypes: " + e.getMessage());
        } catch (Exception e) {
            throw new Exception("GetTableColumnNamesTypes: " + e.getMessage());
        }
    }

    /**
     * Check Schema Validity
     *
     * @param schema
     * @throws Exception
     */
    public void checkSchemaValidity(ArrayList<JsonColumn> schema) throws Exception {
        for (int i = 0; i < schema.size(); i++) {
            JSONObject jsSch = new JSONObject();
            ArrayList<String> keys = schema.get(i).getKeys();
            if (keys.contains("column")) {
                jsSch.put("column", schema.get(i).getColumn());
            }
            if (keys.contains("value")) {
                jsSch.put("value", schema.get(i).getValue());
            }
            if (keys.contains("foreignkey")) {
                jsSch.put("foreignkey", schema.get(i).getForeignkey());
            }
            if (keys.contains("constraint")) {
                jsSch.put("constraint", schema.get(i).getConstraint());
            }
            boolean isValid = uJCol.isSchema(jsSch);
            if (!isValid) {
                throw new Exception("checkSchemaValidity: schema[" + i + "] not valid");
            }
        }
        return;
    }

    /**
     * Check Indexes Validity
     *
     * @param indexes
     * @throws Exception
     */
    public void checkIndexesValidity(ArrayList<JsonIndex> indexes) throws Exception {
        for (int i = 0; i < indexes.size(); i++) {
            JSONObject jsIdx = new JSONObject();
            ArrayList<String> keys = indexes.get(i).getKeys();
            if (keys.contains("value")) {
                jsIdx.put("value", indexes.get(i).getValue());
            }
            if (keys.contains("name")) {
                jsIdx.put("name", indexes.get(i).getName());
            }
            if (keys.contains("mode")) {
                String mode = indexes.get(i).getMode();
                if (mode.length() > 0 && mode.equals("UNIQUE")) {
                    jsIdx.put("mode", mode);
                }
            }
            boolean isValid = uJIdx.isIndexes(jsIdx);
            if (!isValid) {
                throw new Exception("checkIndexesValidity: indexes[" + i + "] not valid");
            }
        }
        return;
    }

    /**
     * Check Triggers Validity
     *
     * @param triggers
     * @throws Exception
     */
    public void checkTriggersValidity(ArrayList<JsonTrigger> triggers) throws Exception {
        for (int i = 0; i < triggers.size(); i++) {
            JSONObject jsTrg = new JSONObject();
            ArrayList<String> keys = triggers.get(i).getKeys();
            if (keys.contains("name")) {
                jsTrg.put("name", triggers.get(i).getName());
            }
            if (keys.contains("timeevent")) {
                jsTrg.put("timeevent", triggers.get(i).getTimeevent());
            }
            if (keys.contains("condition")) {
                jsTrg.put("condition", triggers.get(i).getCondition());
            }
            if (keys.contains("logic")) {
                jsTrg.put("logic", triggers.get(i).getLogic());
            }
            boolean isValid = uJTrg.isTrigger(jsTrg);
            if (!isValid) {
                throw new Exception("checkTriggersValidity: triggers[" + i + "] not valid");
            }
        }
        return;
    }

    /**
     * Get Tables Values
     *
     * @param mDb
     * @param query
     * @param tableName
     * @return
     * @throws Exception
     */
    public ArrayList<ArrayList<Object>> getValues(Database mDb, String query, String tableName) throws Exception {
        ArrayList<ArrayList<Object>> values = new ArrayList<>();
        try {
            JSObject tableNamesTypes = getTableColumnNamesTypes(mDb, tableName);
            ArrayList<String> rowTypes = new ArrayList<>();
            ArrayList<String> rowNames = new ArrayList<>();
            if (tableNamesTypes.has("names")) {
                rowNames = getColumnNames(tableNamesTypes.get("names"));
            } else {
                throw new Exception("GetValues: Table " + tableName + " no names");
            }
            if (tableNamesTypes.has("types")) {
                rowTypes = getColumnNames(tableNamesTypes.get("types"));
            } else {
                throw new Exception("GetValues: Table " + tableName + " no types");
            }
            JSArray retValues = mDb.selectSQL(query, new ArrayList<Object>());
            List<JSObject> lValues = retValues.toList();
            if (lValues.size() > 0) {
                for (int j = 0; j < lValues.size(); j++) {
                    ArrayList<Object> row = createRowValues(lValues, j, rowNames, rowTypes);
                    values.add(row);
                }
            }
        } catch (Exception e) {
            throw new Exception("GetValues: " + e.getMessage());
        } finally {
            return values;
        }
    }

    /**
     * Get Table Row Values
     * @param values
     * @param pos
     * @param rowNames
     * @param rowTypes
     * @return
     */
    public ArrayList<Object> createRowValues(List<JSObject> values, int pos, ArrayList<String> rowNames, ArrayList<String> rowTypes)
        throws Exception {
        ArrayList<Object> row = new ArrayList<>();
        for (int k = 0; k < rowNames.size(); k++) {
            String nType = rowTypes.get(k);
            String nName = rowNames.get(k);

            if (values.get(pos).has(nName)) {
                Object obj = values.get(pos).get(nName);
                if (obj.toString().equals("null")) {
                    row.add(JSONObject.NULL);
                } else if (obj instanceof Long) {
                    row.add(values.get(pos).getLong(nName));
                } else if (obj instanceof String) {
                    row.add(values.get(pos).getString(nName));
                } else if (obj instanceof Double) {
                    row.add(values.get(pos).getDouble(nName));
                }
            } else {
                String msg = "value is not (string, nsnull," + "int64,double";
                throw new Exception("CreateRowValues: " + msg);
            }
        }
        return row;
    }
}
