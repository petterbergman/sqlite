import type { Database as SqlJsDatabase } from 'sql.js';

import type { JsonColumn, JsonIndex, JsonSQLite, JsonTable, JsonTrigger, JsonView } from '../definitions';

import { inTransaction, selectRows, toSqlValues } from './database';
import type { WebDatabase } from './database';

// Same rules as JsonSQLite.isJsonSQLite on Android and iOS: "encrypted" and "mode" are accepted
// for compatibility, but only an unencrypted "full" import is supported
export function isJsonSQLite(obj: any): obj is JsonSQLite {
  if (!isObject(obj)) return false;
  for (const [key, value] of Object.entries(obj)) {
    switch (key) {
      case 'database':
        if (typeof value !== 'string') return false;
        break;
      case 'version':
        if (!Number.isInteger(value)) return false;
        break;
      case 'overwrite':
        if (typeof value !== 'boolean') return false;
        break;
      case 'encrypted':
        if (value !== false) return false;
        break;
      case 'mode':
        if (value !== 'full') return false;
        break;
      case 'tables':
        if (!Array.isArray(value) || !value.every(isTable)) return false;
        break;
      case 'views':
        if (!Array.isArray(value) || !value.every(isView)) return false;
        break;
      default:
        return false;
    }
  }
  return true;
}

function isObject(obj: any): obj is Record<string, any> {
  return obj !== null && typeof obj === 'object' && !Array.isArray(obj) && Object.keys(obj).length > 0;
}

function hasOnlyStrings(obj: any, keys: string[]): boolean {
  return isObject(obj) && Object.entries(obj).every(([k, v]) => keys.includes(k) && typeof v === 'string');
}

function isTable(obj: any): boolean {
  if (!isObject(obj)) return false;
  const tableKeys = ['name', 'schema', 'indexes', 'triggers', 'values'];
  if (!Object.keys(obj).every((k) => tableKeys.includes(k))) return false;
  if ('name' in obj && typeof obj.name !== 'string') return false;
  for (const key of ['schema', 'indexes', 'triggers', 'values']) {
    if (key in obj && !Array.isArray(obj[key])) return false;
  }
  if (obj.schema && !obj.schema.every((c: any) => hasOnlyStrings(c, ['column', 'value', 'foreignkey', 'constraint']))) {
    return false;
  }
  if (obj.indexes && !obj.indexes.every(isIndex)) return false;
  if (obj.triggers && !obj.triggers.every((t: any) => hasOnlyStrings(t, ['name', 'timeevent', 'condition', 'logic']))) {
    return false;
  }
  const nbColumn = (obj.schema ?? []).filter((c: JsonColumn) => c.column).length;
  if (obj.values && nbColumn > 0) {
    if (!obj.values.every((row: any) => Array.isArray(row) && row.length === nbColumn)) return false;
  }
  return true;
}

function isIndex(obj: any): boolean {
  return (
    hasOnlyStrings(obj, ['name', 'value', 'mode']) && (obj.mode === undefined || obj.mode.toUpperCase() === 'UNIQUE')
  );
}

function isView(obj: any): boolean {
  return hasOnlyStrings(obj, ['name', 'value']);
}

/**
 * Replaces the database's schema and data with the JSON object, like ImportFromJson on Android.
 */
export function importJson(mDb: WebDatabase, json: JsonSQLite): number {
  const db = mDb.raw();
  let changes = 0;
  db.exec('PRAGMA foreign_keys = OFF');
  try {
    if (json.tables.length > 0) {
      db.exec(`PRAGMA user_version = ${json.version}`);
      dropAll(db);
      changes = inTransaction(db, true, () => {
        for (const stmt of schemaStatements(json.tables)) db.exec(stmt);
      });
      changes += inTransaction(db, true, () => {
        for (const table of json.tables) {
          if (table.values && table.values.length > 0) insertValues(db, table.name, table.values);
        }
      });
    }
    if (json.views && json.views.length > 0) {
      changes += inTransaction(db, true, () => {
        for (const view of json.views ?? []) {
          if (!view.name || !view.value) throw new Error('CreateViews: no name and value');
          db.exec(`CREATE VIEW IF NOT EXISTS ${view.name} AS ${view.value} ;`);
        }
      });
    }
  } finally {
    db.exec('PRAGMA foreign_keys = ON');
  }
  return changes;
}

function dropAll(db: SqlJsDatabase): void {
  const filters: Record<string, string> = {
    table: "AND name NOT LIKE 'sync_table' AND name NOT LIKE '_temp_%' AND name NOT LIKE 'android_%'",
    index: '',
    trigger: '',
    view: '',
  };
  inTransaction(db, true, () => {
    for (const [type, filter] of Object.entries(filters)) {
      const stmt = `SELECT name FROM sqlite_master WHERE type='${type}' AND name NOT LIKE 'sqlite_%' ${filter};`;
      for (const { name } of selectRows(db, stmt)) {
        db.exec(`DROP ${type.toUpperCase()} IF EXISTS ${name};`);
      }
    }
  });
  db.exec('VACUUM;');
}

function schemaStatements(tables: JsonTable[]): string[] {
  const statements: string[] = [];
  for (const table of tables) {
    if (table.schema && table.schema.length > 0) {
      const definitions: string[] = [];
      for (const c of table.schema) {
        if (c.column) definitions.push(`${c.column} ${c.value}`);
        else if (c.foreignkey) definitions.push(`FOREIGN KEY (${c.foreignkey}) ${c.value}`);
        else if (c.constraint) definitions.push(`CONSTRAINT ${c.constraint} ${c.value}`);
      }
      statements.push(`CREATE TABLE IF NOT EXISTS ${table.name} (${definitions.join(',')});`);
    }
    for (const index of table.indexes ?? []) {
      const unique = index.mode ? `${index.mode} ` : '';
      statements.push(`CREATE ${unique}INDEX IF NOT EXISTS ${index.name} ON ${table.name} (${index.value});`);
    }
    for (const trigger of table.triggers ?? []) {
      const timeEvent = trigger.timeevent.replace(/ ON$/i, '');
      const condition = trigger.condition ? `${trigger.condition} ` : '';
      statements.push(
        `CREATE TRIGGER IF NOT EXISTS ${trigger.name} ${timeEvent} ON ${table.name} ${condition}${trigger.logic}`,
      );
    }
  }
  return statements;
}

function insertValues(db: SqlJsDatabase, tableName: string, values: any[][]): void {
  const columns = columnNames(db, tableName);
  if (columns.length === 0) throw new Error(`CreateTableData: Table ${tableName} does not exist`);
  const stmt = db.prepare(
    `INSERT INTO ${tableName} (${columns.join(',')}) VALUES (${columns.map(() => '?').join(',')});`,
  );
  try {
    for (const row of values) stmt.run(toSqlValues(row));
  } finally {
    stmt.free();
  }
}

function columnNames(db: SqlJsDatabase, tableName: string): string[] {
  return selectRows(db, `PRAGMA table_info('${tableName}');`).map((row) => row.name);
}

/**
 * Exports the whole database as a JSON object, like ExportToJson on Android. Returns null when
 * the database has no tables.
 */
export function exportJson(mDb: WebDatabase): JsonSQLite | null {
  const db = mDb.raw();
  const views: JsonView[] = selectRows(
    db,
    "SELECT name,sql FROM sqlite_master WHERE type = 'view' AND name NOT LIKE 'sqlite_%';",
  ).map((row) => ({ name: row.name, value: row.sql.substring(row.sql.indexOf('AS ') + 3) }));
  const resTables = selectRows(
    db,
    "SELECT name,sql FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%';",
  );
  if (resTables.length === 0) throw new Error("CreateExportObject: table's names failed");

  const tables: JsonTable[] = resTables.map(({ name, sql }) => {
    const table: JsonTable = { name, schema: getSchema(sql) };
    const indexes = getIndexes(db, name);
    if (indexes.length > 0) table.indexes = indexes;
    const triggers = getTriggers(db, name);
    if (triggers.length > 0) table.triggers = triggers;
    const columns = columnNames(db, name);
    const values = selectRows(db, `SELECT * FROM ${name};`).map((row) => columns.map((c) => row[c] ?? null));
    if (values.length > 0) table.values = values;
    return table;
  });
  if (tables.length === 0) return null;
  const json: JsonSQLite = {
    database: mDb.fileName.slice(0, -'SQLite.db'.length),
    version: mDb.version,
    tables,
  };
  if (views.length > 0) json.views = views;
  return json;
}

function getSchema(sqlStmt: string): JsonColumn[] {
  const body = modEmbeddedParentheses(sqlStmt.substring(sqlStmt.indexOf('(') + 1, sqlStmt.lastIndexOf(')')));
  return body.split(',').map((s) => {
    const sc = s.replace(/\n/g, '').trim();
    const [first, rest = ''] = splitFirstWord(sc);
    const column = {} as JsonColumn;
    let value = rest;
    switch (first.toUpperCase()) {
      case 'FOREIGN': {
        const oPar = sc.indexOf('(');
        const cPar = sc.indexOf(')');
        column.foreignkey = sc.substring(oPar + 1, cPar).replace(/§/g, ',');
        value = sc.substring(cPar + 2);
        break;
      }
      case 'PRIMARY':
      case 'UNIQUE': {
        const prefix = first.toUpperCase() === 'PRIMARY' ? 'CPK_' : 'CUN_';
        const oPar = sc.indexOf('(');
        const cPar = sc.indexOf(')');
        column.constraint = (prefix + sc.substring(oPar + 1, cPar).replace(/§/g, '_')).replace(/_ /g, '_');
        value = sc.substring(0, cPar + 1);
        break;
      }
      case 'CONSTRAINT': {
        const [name, constraint = ''] = splitFirstWord(rest.trim());
        column.constraint = name;
        value = constraint;
        break;
      }
      default:
        column.column = first;
    }
    column.value = value.replace(/§/g, ',');
    return column;
  });
}

function splitFirstWord(s: string): [string, string?] {
  const match = /^(\S+)\s+([\s\S]*)$/.exec(s);
  return match ? [match[1], match[2]] : [s];
}

/**
 * Replaces the commas inside parentheses by '§' so the column definitions can be split on ','.
 */
function modEmbeddedParentheses(sstr: string): string {
  const oPars = indicesOf(sstr, '(');
  const cPars = indicesOf(sstr, ')');
  if (oPars.length !== cPars.length) {
    throw new Error('ModEmbeddedParentheses: Not same number of opening and closing parentheses');
  }
  if (oPars.length === 0) return sstr;
  let resStmt = sstr.substring(0, oPars[0] - 1);
  for (let i = 0; i < oPars.length; i++) {
    let str: string;
    if (i < oPars.length - 1 && oPars[i + 1] < cPars[i]) {
      str = sstr.substring(oPars[i] - 1, cPars[i + 1]);
      i++;
    } else {
      str = sstr.substring(oPars[i] - 1, cPars[i]);
    }
    resStmt += str.replace(/,/g, '§');
    if (i < oPars.length - 1) {
      resStmt += sstr.substring(cPars[i], oPars[i + 1] - 1);
    }
  }
  resStmt += sstr.substring(cPars[cPars.length - 1]);
  return resStmt;
}

function indicesOf(str: string, char: string): number[] {
  const indices: number[] = [];
  for (let i = str.indexOf(char); i !== -1; i = str.indexOf(char, i + 1)) indices.push(i);
  return indices;
}

function getIndexes(db: SqlJsDatabase, tableName: string): JsonIndex[] {
  const stmt = `SELECT name,tbl_name,sql FROM sqlite_master WHERE type = 'index' AND tbl_name = '${tableName}' AND sql NOTNULL;`;
  return selectRows(db, stmt).map((row) => {
    const sql: string = row.sql;
    const index: JsonIndex = {
      name: row.name,
      value: sql.substring(sql.lastIndexOf('(') + 1, sql.lastIndexOf(')')),
    };
    if (sql.includes('UNIQUE')) index.mode = 'UNIQUE';
    return index;
  });
}

function getTriggers(db: SqlJsDatabase, tableName: string): JsonTrigger[] {
  const msg = 'GetTriggers: ';
  const stmt = `SELECT name,tbl_name,sql FROM sqlite_master WHERE type = 'trigger' AND tbl_name = '${tableName}' AND sql NOTNULL;`;
  return selectRows(db, stmt).map((row) => {
    const name: string = row.name;
    let sqlArr = (row.sql as string).split(name);
    if (sqlArr.length !== 2) throw new Error(`${msg}sql split name does not return 2 values`);
    if (!sqlArr[1].includes(tableName)) throw new Error(`${msg}sql split does not contains ${tableName}`);
    let timeEvent = sqlArr[1].split(tableName)[0].trim();
    sqlArr = sqlArr[1].split(`${timeEvent} ${tableName}`);
    if (sqlArr.length !== 2) throw new Error(`${msg}sql split tableName does not return 2 values`);
    let condition = '';
    let logic: string;
    if (sqlArr[1].trim().substring(0, 5).toUpperCase() !== 'BEGIN') {
      sqlArr = sqlArr[1].trim().split('BEGIN');
      if (sqlArr.length !== 2) throw new Error(`${msg}sql split BEGIN does not return 2 values`);
      condition = sqlArr[0].trim();
      logic = `BEGIN${sqlArr[1]}`;
    } else {
      logic = sqlArr[1].trim();
    }
    timeEvent = timeEvent.replace(/ ON$/i, '');
    const trigger: JsonTrigger = { name, timeevent: timeEvent, logic };
    if (condition.length > 0) trigger.condition = condition;
    return trigger;
  });
}
