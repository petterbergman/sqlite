/**
 * CapacitorSQLitePlugin Interface
 */
export interface CapacitorSQLitePlugin {
  /**
   * Initialize the web store
   *
   * @return Promise<void>
   * @since 3.2.3-1
   */

  initWebStore(): Promise<void>;
  /**
   * Save database to  the web store
   *
   * @param options: capSQLiteOptions
   * @return Promise<void>
   * @since 3.2.3-1
   */

  saveToStore(options: capSQLiteOptions): Promise<void>;
  /**
   * create a database connection
   * @param options capConnectionOptions
   * @return Promise<void>
   * @since 2.9.0 refactor
   */
  createConnection(options: capConnectionOptions): Promise<void>;
  /**
   * close a database connection
   * @param options capSQLiteOptions
   * @return Promise<void>
   * @since 2.9.0 refactor
   */
  closeConnection(options: capSQLiteOptions): Promise<void>;
  /**
   * Opens a SQLite database.
   * Attention: This re-opens a database if it's already open!
   *
   * @param options: capSQLiteOptions
   * @returns Promise<void>
   * @since 0.0.1
   */
  open(options: capSQLiteOptions): Promise<void>;
  /**
   * Close a SQLite database
   * @param options: capSQLiteOptions
   * @returns Promise<void>
   * @since 0.0.1
   */
  close(options: capSQLiteOptions): Promise<void>;
  /**
   * Execute a Batch of Raw Statements as String
   * @param options: capSQLiteExecuteOptions
   * @returns Promise<capSQLiteChanges>
   * @since 0.0.1
   */
  execute(options: capSQLiteExecuteOptions): Promise<capSQLiteChanges>;
  /**
   * Execute a Set of Raw Statements as Array of CapSQLiteSet
   * @param options: capSQLiteSetOptions
   * @returns Promise<capSQLiteChanges>
   * @since 2.2.0-2
   */
  executeSet(options: capSQLiteSetOptions): Promise<capSQLiteChanges>;
  /**
   * Execute a Single Statement
   * @param options: capSQLiteRunOptions
   * @returns Promise<capSQLiteChanges>
   * @since 0.0.1
   */
  run(options: capSQLiteRunOptions): Promise<capSQLiteChanges>;
  /**
   * Query a Single Statement
   * @param options: capSQLiteQueryOptions
   * @returns Promise<capSQLiteValues>
   * @since 0.0.1
   */
  query(options: capSQLiteQueryOptions): Promise<capSQLiteValues>;
  /**
   * Check if a SQLite database is opened
   * @param options: capSQLiteOptions
   * @returns Promise<capSQLiteResult>
   * @since 3.0.0-beta.5
   */
  isDBOpen(options: capSQLiteOptions): Promise<capSQLiteResult>;
  /**
   * Check if a SQLite database exists without connection
   * @param options: capSQLiteOptions
   * @returns Promise<capSQLiteResult>
   * @since 3.0.0-beta.5
   */
  isDatabase(options: capSQLiteOptions): Promise<capSQLiteResult>;
  /**
   * Is Json Object Valid
   * @param options: capSQLiteImportOptions
   * @returns Promise<capSQLiteResult>
   * @since 2.0.1-1
   */
  isJsonValid(options: capSQLiteImportOptions): Promise<capSQLiteResult>;
  /**
   * Import from Json Object
   * @param options: capSQLiteImportOptions
   * @returns Promise<capSQLiteChanges>
   * @since 2.0.0-3
   */
  importFromJson(options: capSQLiteImportOptions): Promise<capSQLiteChanges>;
  /**
   * Export the whole database to a Json Object
   * @param options: capSQLiteOptions
   * @returns Promise<capSQLiteJson>
   * @since 2.0.1-1
   */
  exportToJson(options: capSQLiteOptions): Promise<capSQLiteJson>;
  /**
   * Check Connection Consistency JS <=> Native
   * return true : consistency, connections are opened
   * return false : no consistency, connections are closed
   * @param options: capAllConnectionsOptions
   * @returns Promise<capSQLiteResult>
   * @since 3.0.0-beta.11
   */
  checkConnectionsConsistency(options: capAllConnectionsOptions): Promise<capSQLiteResult>;
}
export interface capConnectionOptions {
  /**
   * The database name
   */
  database?: string;
  /**
   * The database  version
   */
  version?: number;
}
export interface capAllConnectionsOptions {
  /**
   * the dbName of all connections
   * @since 3.0.0-beta.10
   */
  dbNames?: string[];
}
export interface capSQLiteOptions {
  /**
   * The database name
   */
  database?: string;
}
export interface capSQLiteExecuteOptions {
  /**
   * The database name
   */
  database?: string;
  /**
   * The batch of raw SQL statements as string
   */
  statements?: string;
  /**
   * Enable / Disable transactions
   * default Enable (true)
   * @since 3.0.0-beta.10
   */
  transaction?: boolean;
}
export interface capSQLiteSetOptions {
  /**
   * The database name
   */
  database?: string;
  /**
   * The batch of raw SQL statements as Array of capSQLLiteSet
   */
  set?: capSQLiteSet[];
  /**
   * Enable / Disable transactions
   * default Enable (true)
   * @since 3.0.0-beta.10
   */
  transaction?: boolean;
}
export interface capSQLiteRunOptions {
  /**
   * The database name
   */
  database?: string;
  /**
   * A statement
   */
  statement?: string;
  /**
   * A set of values for a statement
   */
  values?: any[];
  /**
   * Enable / Disable transactions
   * default Enable (true)
   * @since 3.0.0-beta.10
   */
  transaction?: boolean;
}
export interface capSQLiteQueryOptions {
  /**
   * The database name
   */
  database?: string;
  /**
   * A statement
   */
  statement?: string;
  /**
   * A set of values for a statement
   * Change to any[]
   * @since 3.0.0-beta.11
   */
  values?: any[];
}
export interface capSQLiteImportOptions {
  /**
   * Set the JSON object to import
   *
   */
  jsonstring?: string;
}
export interface capSQLiteSet {
  /**
   * A statement
   */
  statement?: string;
  /**
   * the data values list as an Array
   */
  values?: any[];
}
export interface capSQLiteResult {
  /**
   * result set to true when successful else false
   */
  result?: boolean;
}
export interface capSQLiteChanges {
  /**
   * a returned Changes
   */
  changes?: Changes;
}
export interface Changes {
  /**
   * the number of changes from an execute or run command
   */
  changes?: number;
  /**
   * the lastId created from a run command
   */
  lastId?: number;
  /**
   * values when RETURNING
   */
  values?: any[];
}
export interface capSQLiteValues {
  /**
   * the data values list as an Array
   * iOS the first row is the returned ios_columns name list
   */
  values?: any[];
}
export interface DBSQLiteValues {
  /**
   * the data values list as an Array
   */
  values?: any[];
}
export interface capSQLiteJson {
  /**
   * an export JSON object
   */
  export?: JsonSQLite;
}

export interface JsonSQLite {
  /**
   * The database name
   */
  database: string;
  /**
   *  The database version
   */
  version: number;
  /**
   * Delete the database prior to import (default false)
   */
  overwrite?: boolean;
  /***
   * Array of Table (JsonTable)
   */
  tables: JsonTable[];
  /***
   * Array of View (JsonView)
   */
  views?: JsonView[];
}
export interface JsonTable {
  /**
   * The database name
   */
  name: string;
  /***
   * Array of Schema (JsonColumn)
   */
  schema?: JsonColumn[];
  /***
   * Array of Index (JsonIndex)
   */
  indexes?: JsonIndex[];
  /***
   * Array of Trigger (JsonTrigger)
   */
  triggers?: JsonTrigger[];
  /***
   * Array of Table data
   */
  values?: any[][];
}
export interface JsonColumn {
  /**
   * The column name
   */
  column?: string;
  /**
   * The column data (type, unique, ...)
   */
  value: string;
  /**
   * The column foreign key constraints
   */
  foreignkey?: string;
  /**
   * the column constraint
   */
  constraint?: string;
}
export interface JsonTrigger {
  /**
   * The trigger name
   */
  name: string;
  /**
   * The trigger time event fired
   */
  timeevent: string;

  /**
   * The trigger condition
   */
  condition?: string;

  /**
   * The logic of the trigger
   */
  logic: string;
}
export interface JsonIndex {
  /**
   * The index name
   */
  name: string;
  /**
   * The value of the index can have the following formats:
   * email
   * email ASC
   * email, MobileNumber
   * email ASC, MobileNumber DESC
   */
  value: string;
  /**
   * the mode (Optional)
   * UNIQUE
   */
  mode?: string;
}
export interface JsonView {
  /**
   * The view name
   */
  name: string;
  /**
   * The view create statement
   */
  value: string;
}

/**
 * SQLiteConnection Interface
 */
export interface ISQLiteConnection {
  /**
   * Init the web store
   * @returns Promise<void>
   * @since 3.2.3-1
   */
  initWebStore(): Promise<void>;
  /**
   * Save the datbase to the web store
   * @param database
   * @returns Promise<void>
   * @since 3.2.3-1
   */
  saveToStore(database: string): Promise<void>;
  /**
   * Create a connection to a database
   * @param database
   * @param version
   * @returns Promise<SQLiteDBConnection>
   * @since 2.9.0 refactor
   */
  createConnection(database: string, version: number): Promise<SQLiteDBConnection>;
  /**
   * Check if a connection exists
   * @param database
   * @returns Promise<capSQLiteResult>
   * @since 3.0.0-beta.5
   */
  isConnection(database: string): Promise<capSQLiteResult>;
  /**
   * Retrieve an existing database connection
   * @param database
   * @returns Promise<SQLiteDBConnection>
   * @since 2.9.0 refactor
   */
  retrieveConnection(database: string): Promise<SQLiteDBConnection>;
  /**
   * Close a database connection
   * @param database
   * @returns Promise<void>
   * @since 2.9.0 refactor
   */
  closeConnection(database: string): Promise<void>;
  /**
   * Close all database connections
   * @returns Promise<void>
   * @since 2.9.0 refactor
   */
  closeAllConnections(): Promise<void>;
  /**
   * Check the consistency between Js Connections
   * and Native Connections
   * if inconsistency all connections are removed
   * @returns Promise<capSQLiteResult>
   * @since 3.0.0-beta.10
   */
  checkConnectionsConsistency(): Promise<capSQLiteResult>;
  /**
   * Import a database From a JSON
   * @param jsonstring string
   * @returns Promise<capSQLiteChanges>
   * @since 2.9.0 refactor
   */
  importFromJson(jsonstring: string): Promise<capSQLiteChanges>;
  /**
   * Check the validity of a JSON Object
   * @param jsonstring string
   * @returns Promise<capSQLiteResult>
   * @since 2.9.0 refactor
   */
  isJsonValid(jsonstring: string): Promise<capSQLiteResult>;
  /**
   * Check if a database exists
   * @param database
   * @returns Promise<capSQLiteResult>
   * @since 3.0.0-beta.5
   */
  isDatabase(database: string): Promise<capSQLiteResult>;
}
/**
 * SQLiteConnection Class
 */
export class SQLiteConnection implements ISQLiteConnection {
  private _connectionDict: Map<string, SQLiteDBConnection> = new Map();
  constructor(private sqlite: any) {}

  async initWebStore(): Promise<void> {
    try {
      await this.sqlite.initWebStore();
      return Promise.resolve();
    } catch (err) {
      return Promise.reject(err);
    }
  }
  async saveToStore(database: string): Promise<void> {
    try {
      await this.sqlite.saveToStore({ database });
      return Promise.resolve();
    } catch (err) {
      return Promise.reject(err);
    }
  }
  async createConnection(database: string, version: number): Promise<SQLiteDBConnection> {
    try {
      if (database.endsWith('.db')) database = database.slice(0, -3);
      await this.sqlite.createConnection({ database, version });
      const conn = new SQLiteDBConnection(database, this.sqlite);
      this._connectionDict.set(database, conn);
      return Promise.resolve(conn);
    } catch (err) {
      return Promise.reject(err);
    }
  }
  async closeConnection(database: string): Promise<void> {
    try {
      if (database.endsWith('.db')) database = database.slice(0, -3);
      await this.sqlite.closeConnection({ database });
      this._connectionDict.delete(database);
      return Promise.resolve();
    } catch (err) {
      return Promise.reject(err);
    }
  }
  async isConnection(database: string): Promise<capSQLiteResult> {
    const res: capSQLiteResult = {} as capSQLiteResult;
    if (database.endsWith('.db')) database = database.slice(0, -3);
    res.result = this._connectionDict.has(database);
    return Promise.resolve(res);
  }
  async retrieveConnection(database: string): Promise<SQLiteDBConnection> {
    if (database.endsWith('.db')) database = database.slice(0, -3);
    const conn = this._connectionDict.get(database);
    if (typeof conn != 'undefined') return Promise.resolve(conn);
    return Promise.reject(`Connection ${database} does not exist`);
  }
  async closeAllConnections(): Promise<void> {
    try {
      for (const database of [...this._connectionDict.keys()]) {
        await this.sqlite.closeConnection({ database });
        this._connectionDict.delete(database);
      }
      return Promise.resolve();
    } catch (err) {
      return Promise.reject(err);
    }
  }
  async checkConnectionsConsistency(): Promise<capSQLiteResult> {
    try {
      const res: capSQLiteResult = await this.sqlite.checkConnectionsConsistency({
        dbNames: [...this._connectionDict.keys()],
      });
      if (!res.result) this._connectionDict = new Map();
      return Promise.resolve(res);
    } catch (err) {
      this._connectionDict = new Map();
      return Promise.reject(err);
    }
  }
  async importFromJson(jsonstring: string): Promise<capSQLiteChanges> {
    try {
      const ret = await this.sqlite.importFromJson({ jsonstring: jsonstring });
      return Promise.resolve(ret);
    } catch (err) {
      return Promise.reject(err);
    }
  }
  async isJsonValid(jsonstring: string): Promise<capSQLiteResult> {
    try {
      const ret = await this.sqlite.isJsonValid({ jsonstring: jsonstring });
      return Promise.resolve(ret);
    } catch (err) {
      return Promise.reject(err);
    }
  }
  async isDatabase(database: string): Promise<capSQLiteResult> {
    if (database.endsWith('.db')) database = database.slice(0, -3);
    try {
      const res = await this.sqlite.isDatabase({ database: database });
      return Promise.resolve(res);
    } catch (err) {
      return Promise.reject(err);
    }
  }
}

/**
 * SQLiteDBConnection Interface
 */
export interface ISQLiteDBConnection {
  /**
   * Get SQLite DB Connection DB name
   * @returns string
   * @since 2.9.0 refactor
   */
  getConnectionDBName(): string;
  /**
   * Open a SQLite DB Connection
   * @returns Promise<void>
   * @since 2.9.0 refactor
   */
  open(): Promise<void>;
  /**
   * Close a SQLite DB Connection
   * @returns Promise<void>
   * @since 2.9.0 refactor
   */
  close(): Promise<void>;
  /**
   * Execute SQLite DB Connection Statements
   * @param statements
   * @param transaction (optional)
   * @returns Promise<capSQLiteChanges>
   * @since 2.9.0 refactor
   */
  execute(statements: string, transaction?: boolean): Promise<capSQLiteChanges>;
  /**
   * Execute SQLite DB Connection Query
   * @param statement
   * @param values (optional)
   * @returns Promise<Promise<DBSQLiteValues>
   * @since 2.9.0 refactor
   */
  query(statement: string, values?: any[]): Promise<DBSQLiteValues>;
  /**
   * Execute SQLite DB Connection Raw Statement
   * @param statement
   * @param values (optional)
   * @param transaction (optional)
   * @returns Promise<capSQLiteChanges>
   * @since 2.9.0 refactor
   */
  run(statement: string, values?: any[], transaction?: boolean): Promise<capSQLiteChanges>;
  /**
   * Execute SQLite DB Connection Set
   * @param set
   * @param transaction (optional)
   * @returns Promise<capSQLiteChanges>
   * @since 2.9.0 refactor
   */
  executeSet(set: capSQLiteSet[], transaction?: boolean): Promise<capSQLiteChanges>;
  /**
   * Check if a SQLite database is opened
   * @returns Promise<capSQLiteResult>
   * @since 3.0.0-beta.5
   */
  isDBOpen(): Promise<capSQLiteResult>;
  /**
   * Export the given database to a JSON Object
   * @returns Promise<capSQLiteJson>
   * @since 2.9.0 refactor
   */
  exportToJson(): Promise<capSQLiteJson>;
}
/**
 * SQLiteDBConnection Class
 */
export class SQLiteDBConnection implements ISQLiteDBConnection {
  constructor(
    private dbName: string,
    private sqlite: any,
  ) {}

  getConnectionDBName(): string {
    return this.dbName;
  }

  async open(): Promise<void> {
    try {
      await this.sqlite.open({ database: this.dbName });
      return Promise.resolve();
    } catch (err) {
      return Promise.reject(err);
    }
  }
  async close(): Promise<void> {
    try {
      await this.sqlite.close({ database: this.dbName });
      return Promise.resolve();
    } catch (err) {
      return Promise.reject(err);
    }
  }
  async execute(statements: string, transaction = true): Promise<capSQLiteChanges> {
    try {
      const res: any = await this.sqlite.execute({
        database: this.dbName,
        statements: statements,
        transaction: transaction,
      });
      return Promise.resolve(res);
    } catch (err) {
      return Promise.reject(err);
    }
  }
  async query(statement: string, values?: any[]): Promise<DBSQLiteValues> {
    try {
      let res: any = await this.sqlite.query({
        database: this.dbName,
        statement: statement,
        values: values && values.length > 0 ? values : [],
      });
      // reorder rows for ios
      res = await this.reorderRows(res);
      return Promise.resolve(res);
    } catch (err) {
      return Promise.reject(err);
    }
  }
  async run(statement: string, values?: any[], transaction = true): Promise<capSQLiteChanges> {
    try {
      const res: any = await this.sqlite.run({
        database: this.dbName,
        statement: statement,
        values: values && values.length > 0 ? values : [],
        transaction: transaction,
      });
      // reorder rows for ios
      res.changes = await this.reorderRows(res.changes);
      return Promise.resolve(res);
    } catch (err) {
      return Promise.reject(err);
    }
  }
  async executeSet(set: capSQLiteSet[], transaction = true): Promise<capSQLiteChanges> {
    try {
      const res: any = await this.sqlite.executeSet({
        database: this.dbName,
        set: set,
        transaction: transaction,
      });
      // reorder rows for ios
      res.changes = await this.reorderRows(res.changes);
      return Promise.resolve(res);
    } catch (err) {
      return Promise.reject(err);
    }
  }
  async isDBOpen(): Promise<capSQLiteResult> {
    try {
      const res: capSQLiteResult = await this.sqlite.isDBOpen({ database: this.dbName });
      return Promise.resolve(res);
    } catch (err) {
      return Promise.reject(err);
    }
  }
  async exportToJson(): Promise<capSQLiteJson> {
    try {
      const res: any = await this.sqlite.exportToJson({ database: this.dbName });
      return Promise.resolve(res);
    } catch (err) {
      return Promise.reject(err);
    }
  }
  private async reorderRows(res: any): Promise<any> {
    const retRes: any = res;
    if (res?.values && typeof res.values[0] === 'object') {
      if (Object.keys(res.values[0]).includes('ios_columns')) {
        const columnList: string[] = res.values[0]['ios_columns'];
        const iosRes: any[] = [];
        for (let i = 1; i < res.values.length; i++) {
          const rowJson: any = res.values[i];
          const resRowJson: any = {};
          for (const item of columnList) {
            resRowJson[item] = rowJson[item];
          }
          iosRes.push(resRowJson);
        }
        retRes['values'] = iosRes;
      }
    }

    return Promise.resolve(retRes);
  }
}
