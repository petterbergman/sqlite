import { WebPlugin } from '@capacitor/core';

import type {
  CapacitorSQLitePlugin,
  capConnectionOptions,
  capAllConnectionsOptions,
  capSQLiteChanges,
  capSQLiteExecuteOptions,
  capSQLiteImportOptions,
  capSQLiteJson,
  capSQLiteOptions,
  capSQLiteQueryOptions,
  capSQLiteResult,
  capSQLiteRunOptions,
  capSQLiteSetOptions,
  capSQLiteValues,
} from './definitions';
import { WebDatabase } from './web/database';
import { exportJson, importJson, isJsonSQLite } from './web/json';
import { WebStore } from './web/store';

/**
 * Runs the plugin on sql.js, keeping each database in IndexedDB. It mirrors the Android and iOS
 * implementations so the app behaves the same when it runs in a browser for development and tests.
 */
export class CapacitorSQLiteWeb extends WebPlugin implements CapacitorSQLitePlugin {
  private readonly store = new WebStore();
  private readonly dbDict = new Map<string, WebDatabase>();

  async initWebStore(): Promise<void> {
    await this.store.open();
  }

  async saveToStore(options: capSQLiteOptions): Promise<void> {
    return this.call('SaveToStore', () => this.getOpenConnection(options.database).save());
  }

  async createConnection(options: capConnectionOptions): Promise<void> {
    return this.call('CreateConnection', () => {
      const dbName = this.dbNameOf(options.database);
      if (this.dbDict.has(dbName)) throw new Error(`Connection ${dbName} already exists`);
      this.dbDict.set(dbName, new WebDatabase(dbName + 'SQLite.db', options.version ?? 1, this.store));
    });
  }

  async open(options: capSQLiteOptions): Promise<void> {
    return this.call('Open', () => this.getConnection(options.database).open());
  }

  async closeConnection(options: capSQLiteOptions): Promise<void> {
    return this.call('CloseConnection', async () => {
      const db = this.getConnection(options.database);
      if (db.isOpen()) await db.close();
      this.dbDict.delete(this.dbNameOf(options.database));
    });
  }

  async checkConnectionsConsistency(options: capAllConnectionsOptions): Promise<capSQLiteResult> {
    return this.call('CheckConnectionsConsistency', async () => {
      const conns = new Set((options.dbNames ?? []).map((name) => this.dbNameOf(name)));
      if (conns.size === 0 || this.dbDict.size < conns.size) {
        // not solvable inconsistency
        await this.closeAllConnections();
        return { result: false };
      }
      // drop connections the JS side no longer knows about
      for (const dbName of [...this.dbDict.keys()]) {
        if (!conns.has(dbName)) this.dbDict.delete(dbName);
      }
      if (this.dbDict.size === conns.size) return { result: true };
      await this.closeAllConnections();
      return { result: false };
    });
  }

  async close(options: capSQLiteOptions): Promise<void> {
    return this.call('Close', () => this.getOpenConnection(options.database).close());
  }

  async execute(options: capSQLiteExecuteOptions): Promise<capSQLiteChanges> {
    return this.call('Execute', async () => {
      if (!options.statements) throw new Error('Must provide raw SQL statements');
      const db = this.getOpenConnection(options.database);
      const changes = await db.execute(options.statements, options.transaction ?? true);
      return { changes: { changes } };
    });
  }

  async executeSet(options: capSQLiteSetOptions): Promise<capSQLiteChanges> {
    return this.call('ExecuteSet', async () => {
      const set = options.set ?? [];
      if (set.length === 0) throw new Error('Must provide a non-empty set of SQL statements');
      if (set.some((s) => Object.keys(s).some((key) => key !== 'statement' && key !== 'values'))) {
        throw new Error('Must provide a set as Array of {statement,values}');
      }
      const db = this.getOpenConnection(options.database);
      return { changes: await db.executeSet(set, options.transaction ?? true) };
    });
  }

  async run(options: capSQLiteRunOptions): Promise<capSQLiteChanges> {
    return this.call('Run', async () => {
      if (!options.statement) throw new Error('Must provide a query statement');
      const db = this.getOpenConnection(options.database);
      return { changes: await db.run(options.statement, options.values, options.transaction ?? true) };
    });
  }

  async query(options: capSQLiteQueryOptions): Promise<capSQLiteValues> {
    return this.call('Query', () => {
      if (!options.statement) throw new Error('Must provide a query statement');
      return { values: this.getOpenConnection(options.database).query(options.statement, options.values) };
    });
  }

  async isDBOpen(options: capSQLiteOptions): Promise<capSQLiteResult> {
    return this.call('IsDBOpen', () => ({ result: this.getConnection(options.database).isOpen() }));
  }

  async isDatabase(options: capSQLiteOptions): Promise<capSQLiteResult> {
    return this.call('IsDatabase', async () => ({
      result: await this.store.has(this.dbNameOf(options.database) + 'SQLite.db'),
    }));
  }

  async isJsonValid(options: capSQLiteImportOptions): Promise<capSQLiteResult> {
    return this.call('IsJsonValid', () => {
      if (!options.jsonstring) throw new Error('Must provide a Stringify Json Object');
      return { result: isJsonSQLite(JSON.parse(options.jsonstring)) };
    });
  }

  async importFromJson(options: capSQLiteImportOptions): Promise<capSQLiteChanges> {
    return this.call('ImportFromJson', async () => {
      if (!options.jsonstring) throw new Error('Must provide a Stringify Json Object');
      const json = JSON.parse(options.jsonstring);
      if (!isJsonSQLite(json)) throw new Error('Stringify Json Object not Valid');
      const fileName = this.dbNameOf(json.database) + 'SQLite.db';
      const version = json.version ?? 1;
      if (json.overwrite) await this.store.remove(fileName);
      const db = new WebDatabase(fileName, version, this.store);
      await db.open();
      try {
        if (db.getTableNames().length > 0) {
          const curVersion = db.getVersion();
          if (version < curVersion) throw new Error(`Cannot import a version lower than ${curVersion}`);
          if (version === curVersion) return { changes: { changes: 0 } };
        }
        return { changes: { changes: importJson(db, json) } };
      } finally {
        await db.close();
      }
    });
  }

  async exportToJson(options: capSQLiteOptions): Promise<capSQLiteJson> {
    return this.call('ExportToJson', () => {
      const json = exportJson(this.getOpenConnection(options.database));
      if (!json) throw new Error('return Object is empty No data to synchronize');
      return { export: json };
    });
  }

  private async closeAllConnections(): Promise<void> {
    for (const dbName of [...this.dbDict.keys()]) {
      await this.closeConnection({ database: dbName });
    }
  }

  /**
   * Strips a trailing ".db", as the native plugins do, so "x" and "x.db" are the same connection.
   */
  private dbNameOf(database: string | undefined): string {
    if (!database) throw new Error('Must provide a database name');
    return !database.includes('/') && database.endsWith('.db') ? database.slice(0, -3) : database;
  }

  private getConnection(database: string | undefined): WebDatabase {
    this.ensureWebStoreIsOpen();
    const dbName = this.dbNameOf(database);
    const db = this.dbDict.get(dbName);
    if (!db) throw new Error(`No available connection for database ${dbName}`);
    return db;
  }

  private getOpenConnection(database: string | undefined): WebDatabase {
    const db = this.getConnection(database);
    if (!db.isOpen()) throw new Error(`database ${this.dbNameOf(database)} not opened`);
    return db;
  }

  private ensureWebStoreIsOpen(): void {
    if (!this.store.isOpen) throw new Error('WebStore is not open yet. You have to call "initWebStore()" first.');
  }

  /**
   * Rejects with the method name in front of the message, like the native plugins.
   */
  private async call<T>(method: string, fn: () => T | Promise<T>): Promise<T> {
    try {
      return await fn();
    } catch (err: any) {
      throw new Error(`${method}: ${err?.message ?? err}`);
    }
  }
}
