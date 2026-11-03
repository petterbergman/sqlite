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

export class CapacitorSQLiteWeb extends WebPlugin implements CapacitorSQLitePlugin {
  private jeepSqliteElement: any = null;
  private isWebStoreOpen = false;

  async initWebStore(): Promise<void> {
    await customElements.whenDefined('jeep-sqlite');

    this.jeepSqliteElement = document.querySelector('jeep-sqlite');
    this.ensureJeepSqliteIsAvailable();

    if (!this.isWebStoreOpen) {
      this.isWebStoreOpen = await this.jeepSqliteElement.isStoreOpen();
    }

    return;
  }

  async saveToStore(options: capSQLiteOptions): Promise<void> {
    this.ensureJeepSqliteIsAvailable();
    this.ensureWebstoreIsOpen();

    try {
      await this.jeepSqliteElement.saveToStore(options);
      return;
    } catch (err) {
      throw new Error(`${err}`);
    }
  }

  async createConnection(options: capConnectionOptions): Promise<void> {
    this.ensureJeepSqliteIsAvailable();
    this.ensureWebstoreIsOpen();

    try {
      await this.jeepSqliteElement.createConnection(options);
      return;
    } catch (err) {
      throw new Error(`${err}`);
    }
  }

  async open(options: capSQLiteOptions): Promise<void> {
    this.ensureJeepSqliteIsAvailable();
    this.ensureWebstoreIsOpen();

    try {
      await this.jeepSqliteElement.open(options);
      return;
    } catch (err) {
      throw new Error(`${err}`);
    }
  }

  async closeConnection(options: capSQLiteOptions): Promise<void> {
    this.ensureJeepSqliteIsAvailable();
    this.ensureWebstoreIsOpen();

    try {
      await this.jeepSqliteElement.closeConnection(options);
      return;
    } catch (err) {
      throw new Error(`${err}`);
    }
  }

  async checkConnectionsConsistency(options: capAllConnectionsOptions): Promise<capSQLiteResult> {
    this.ensureJeepSqliteIsAvailable();

    try {
      // jeep-sqlite still keys its connections by open mode; every connection is read-write
      const dbNames = options.dbNames ?? [];
      const consistencyResult: capSQLiteResult = await this.jeepSqliteElement.checkConnectionsConsistency({
        dbNames,
        openModes: dbNames.map(() => 'RW'),
      });
      return consistencyResult;
    } catch (err) {
      throw new Error(`${err}`);
    }
  }

  async close(options: capSQLiteOptions): Promise<void> {
    this.ensureJeepSqliteIsAvailable();
    this.ensureWebstoreIsOpen();

    try {
      await this.jeepSqliteElement.close(options);
      return;
    } catch (err) {
      throw new Error(`${err}`);
    }
  }

  async execute(options: capSQLiteExecuteOptions): Promise<capSQLiteChanges> {
    this.ensureJeepSqliteIsAvailable();
    this.ensureWebstoreIsOpen();

    try {
      const executeResult: capSQLiteChanges = await this.jeepSqliteElement.execute(options);
      return executeResult;
    } catch (err) {
      throw new Error(`${err}`);
    }
  }

  async executeSet(options: capSQLiteSetOptions): Promise<capSQLiteChanges> {
    this.ensureJeepSqliteIsAvailable();
    this.ensureWebstoreIsOpen();

    try {
      const executeResult: capSQLiteChanges = await this.jeepSqliteElement.executeSet(options);
      return executeResult;
    } catch (err) {
      throw new Error(`${err}`);
    }
  }

  async run(options: capSQLiteRunOptions): Promise<capSQLiteChanges> {
    this.ensureJeepSqliteIsAvailable();
    this.ensureWebstoreIsOpen();

    try {
      const runResult: capSQLiteChanges = await this.jeepSqliteElement.run(options);
      return runResult;
    } catch (err) {
      throw new Error(`${err}`);
    }
  }
  async query(options: capSQLiteQueryOptions): Promise<capSQLiteValues> {
    this.ensureJeepSqliteIsAvailable();
    this.ensureWebstoreIsOpen();

    try {
      const queryResult: capSQLiteValues = await this.jeepSqliteElement.query(options);
      return queryResult;
    } catch (err) {
      throw new Error(`${err}`);
    }
  }

  async isDBOpen(options: capSQLiteOptions): Promise<capSQLiteResult> {
    this.ensureJeepSqliteIsAvailable();
    this.ensureWebstoreIsOpen();

    try {
      const isDBOpenResult: capSQLiteResult = await this.jeepSqliteElement.isDBOpen(options);
      return isDBOpenResult;
    } catch (err) {
      throw new Error(`${err}`);
    }
  }

  async isDatabase(options: capSQLiteOptions): Promise<capSQLiteResult> {
    this.ensureJeepSqliteIsAvailable();
    this.ensureWebstoreIsOpen();

    try {
      const isDatabaseResult: capSQLiteResult = await this.jeepSqliteElement.isDatabase(options);
      return isDatabaseResult;
    } catch (err) {
      throw new Error(`${err}`);
    }
  }

  async isJsonValid(options: capSQLiteImportOptions): Promise<capSQLiteResult> {
    this.ensureJeepSqliteIsAvailable();
    this.ensureWebstoreIsOpen();

    try {
      const isJsonValidResult = await this.jeepSqliteElement.isJsonValid(options);
      return isJsonValidResult;
    } catch (err) {
      throw new Error(`${err}`);
    }
  }

  async importFromJson(options: capSQLiteImportOptions): Promise<capSQLiteChanges> {
    this.ensureJeepSqliteIsAvailable();
    this.ensureWebstoreIsOpen();

    try {
      const importFromJsonResult: capSQLiteChanges = await this.jeepSqliteElement.importFromJson(options);
      return importFromJsonResult;
    } catch (err) {
      throw new Error(`${err}`);
    }
  }

  async exportToJson(options: capSQLiteOptions): Promise<capSQLiteJson> {
    this.ensureJeepSqliteIsAvailable();
    this.ensureWebstoreIsOpen();

    try {
      const exportToJsonResult: capSQLiteJson = await this.jeepSqliteElement.exportToJson({
        ...options,
        jsonexportmode: 'full',
      });
      return exportToJsonResult;
    } catch (err) {
      throw new Error(`${err}`);
    }
  }

  /**
   * Checks if the `jeep-sqlite` element is present in the DOM.
   * If it's not in the DOM, this method throws an Error.
   *
   * Attention: This will always fail, if the `intWebStore()` method wasn't called before.
   */
  private ensureJeepSqliteIsAvailable() {
    if (this.jeepSqliteElement === null) {
      throw new Error(
        `The jeep-sqlite element is not present in the DOM! Please check the @capacitor-community/sqlite documentation for instructions regarding the web platform.`,
      );
    }
  }

  private ensureWebstoreIsOpen() {
    if (!this.isWebStoreOpen) {
      throw new Error('WebStore is not open yet. You have to call "initWebStore()" first.');
    }
  }
}
