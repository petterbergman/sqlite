import initSqlJs from 'sql.js';
import type { Database as SqlJsDatabase, SqlJsStatic, SqlValue } from 'sql.js';

import type { WebStore } from './store';

// The app copies sql-wasm.wasm here from the same sql.js package this module imports
const WASM_PATH = '/assets';

let sqlJs: Promise<SqlJsStatic> | null = null;

function loadSqlJs(): Promise<SqlJsStatic> {
  if (!sqlJs) {
    sqlJs = initSqlJs({ locateFile: (file: string) => `${WASM_PATH}/${file}` }).catch((err) => {
      sqlJs = null;
      throw err;
    });
  }
  return sqlJs;
}

/**
 * Binds like the native plugins: undefined becomes NULL and a number array becomes a BLOB.
 */
export function toSqlValues(values: any[] | undefined): SqlValue[] {
  return (values ?? []).map((v) => {
    if (v === undefined) return null;
    if (Array.isArray(v)) return Uint8Array.from(v);
    return v;
  });
}

/**
 * Returns BLOBs as number arrays, the way the native plugins hand them over the bridge.
 */
function fromSqlValue(v: SqlValue): any {
  return v instanceof Uint8Array ? Array.from(v) : v;
}

export function selectRows(db: SqlJsDatabase, statement: string, values?: any[]): Record<string, any>[] {
  const rows: Record<string, any>[] = [];
  const stmt = db.prepare(statement);
  try {
    if (values && values.length > 0) stmt.bind(toSqlValues(values));
    const columns = stmt.getColumnNames();
    while (stmt.step()) {
      const row: Record<string, any> = {};
      stmt.get().forEach((v, i) => (row[columns[i]] = fromSqlValue(v)));
      rows.push(row);
    }
  } finally {
    stmt.free();
  }
  return rows;
}

export function totalChanges(db: SqlJsDatabase): number {
  return db.exec('SELECT total_changes()')[0].values[0][0] as number;
}

function lastInsertId(db: SqlJsDatabase): number {
  return db.exec('SELECT last_insert_rowid()')[0].values[0][0] as number;
}

/**
 * Runs fn, inside a transaction when asked, and returns the number of rows it changed.
 */
export function inTransaction(db: SqlJsDatabase, transaction: boolean, fn: () => void): number {
  const initChanges = totalChanges(db);
  if (transaction) db.exec('BEGIN TRANSACTION');
  try {
    fn();
    if (transaction) db.exec('COMMIT TRANSACTION');
  } catch (err) {
    if (transaction) {
      try {
        db.exec('ROLLBACK TRANSACTION');
      } catch {
        // SQLite already rolled back on the failing statement
      }
    }
    throw err;
  }
  return totalChanges(db) - initChanges;
}

/**
 * One SQLite database held in memory by sql.js and written back to the web store after every change.
 */
export class WebDatabase {
  private db: SqlJsDatabase | null = null;

  constructor(
    readonly fileName: string,
    readonly version: number,
    private readonly store: WebStore,
  ) {}

  isOpen(): boolean {
    return this.db !== null;
  }

  /**
   * The open sql.js database, for the JSON import and export.
   */
  raw(): SqlJsDatabase {
    if (!this.db) throw new Error('Database not opened');
    return this.db;
  }

  async open(): Promise<void> {
    if (this.db) return;
    const SQL = await loadSqlJs();
    const data = await this.store.get(this.fileName);
    this.db = data ? new SQL.Database(data) : new SQL.Database();
    try {
      await this.save();
    } catch (err) {
      this.db.close();
      this.db = null;
      throw err;
    }
  }

  async close(): Promise<void> {
    if (!this.db) throw new Error('Database not opened');
    await this.save();
    this.db.close();
    this.db = null;
  }

  async save(): Promise<void> {
    const db = this.raw();
    await this.store.set(this.fileName, db.export());
    // export() closes and reopens the database, which resets the pragmas
    db.exec('PRAGMA foreign_keys = ON');
  }

  getVersion(): number {
    return this.raw().exec('PRAGMA user_version')[0].values[0][0] as number;
  }

  getTableNames(): string[] {
    const stmt =
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sync_table' " +
      "AND name NOT LIKE '_temp_%' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%' " +
      'ORDER BY rootpage DESC;';
    return selectRows(this.raw(), stmt).map((row) => row.name);
  }

  async execute(statements: string, transaction: boolean): Promise<number> {
    const db = this.raw();
    return this.write(() => inTransaction(db, transaction, () => db.exec(statements)));
  }

  async executeSet(
    set: { statement?: string; values?: any[] }[],
    transaction: boolean,
  ): Promise<{ changes: number; lastId: number }> {
    const db = this.raw();
    let lastId = -1;
    const changes = await this.write(() =>
      inTransaction(db, transaction, () => {
        for (const { statement, values } of set) {
          db.run(statement ?? '', toSqlValues(values));
          lastId = lastInsertId(db);
        }
      }),
    );
    return { changes, lastId };
  }

  async run(
    statement: string,
    values: any[] | undefined,
    transaction: boolean,
  ): Promise<{ changes: number; lastId: number }> {
    const db = this.raw();
    let lastId = -1;
    const changes = await this.write(() =>
      inTransaction(db, transaction, () => {
        db.run(statement, toSqlValues(values));
        lastId = lastInsertId(db);
      }),
    );
    return { changes, lastId };
  }

  query(statement: string, values?: any[]): Record<string, any>[] {
    return selectRows(this.raw(), statement, values);
  }

  /**
   * Saves even when fn fails, so a rolled back write leaves the stored file as it was in memory.
   */
  private async write(fn: () => number): Promise<number> {
    try {
      return fn();
    } finally {
      await this.save();
    }
  }
}
