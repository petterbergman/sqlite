import { IDBFactory } from 'fake-indexeddb';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import initSqlJs from 'sql.js';
import type * as SqlJs from 'sql.js';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import type { JsonSQLite } from '../../src/definitions';
import { CapacitorSQLiteWeb } from '../../src/web';

// In Node sql.js finds its wasm next to its own files, not at the app's /assets path
vi.mock('sql.js', async (importOriginal) => {
  const actual = await importOriginal<typeof SqlJs>();
  return { default: () => actual.default() };
});

// The fixture the iOS and Android tests import
const basicJson = readFileSync(fileURLToPath(new URL('../../ios/PluginTests/basic.json', import.meta.url)), 'utf8');

let sqlite: CapacitorSQLiteWeb;

beforeEach(async () => {
  // a fresh, empty IndexedDB for every test
  globalThis.indexedDB = new IDBFactory();
  sqlite = new CapacitorSQLiteWeb();
  await sqlite.initWebStore();
});

async function openDb(database: string, version = 1): Promise<void> {
  await sqlite.createConnection({ database, version });
  await sqlite.open({ database });
}

async function count(database: string, table: string): Promise<number> {
  const res = await sqlite.query({ database, statement: `SELECT COUNT(*) AS cnt FROM ${table}` });
  return res.values?.[0].cnt;
}

const schemaSql = `
  CREATE TABLE IF NOT EXISTS owners (id INTEGER PRIMARY KEY NOT NULL, name TEXT NOT NULL);
  CREATE TABLE IF NOT EXISTS boats (
    id INTEGER PRIMARY KEY NOT NULL,
    owner_id INTEGER NOT NULL,
    name TEXT,
    photo BLOB,
    FOREIGN KEY (owner_id) REFERENCES owners(id) ON DELETE CASCADE
  );`;

describe('JSON import and export (same as the native tests)', () => {
  it('imports basic.json, queries it and exports it back', async () => {
    expect(await sqlite.isJsonValid({ jsonstring: basicJson })).toEqual({ result: true });
    const res = await sqlite.importFromJson({ jsonstring: basicJson });
    expect(res.changes?.changes).toBeGreaterThanOrEqual(0);

    await openDb('testjson_file');
    expect(await count('testjson_file', 'users')).toBe(2);

    const exported = (await sqlite.exportToJson({ database: 'testjson_file' })).export;
    expect(exported?.database).toBe('testjson_file');
    expect(exported?.tables[0].name).toBe('users');
    expect(exported?.tables[0].values).toHaveLength(2);

    await sqlite.close({ database: 'testjson_file' });
    await sqlite.closeConnection({ database: 'testjson_file' });
    expect(await sqlite.isDatabase({ database: 'testjson_file' })).toEqual({ result: true });
  });

  it('rejects a partial JSON object', async () => {
    const json = basicJson.replace('"full"', '"partial"');
    expect(await sqlite.isJsonValid({ jsonstring: json })).toEqual({ result: false });
    await expect(sqlite.importFromJson({ jsonstring: json })).rejects.toThrow(
      'ImportFromJson: Stringify Json Object not Valid',
    );
  });

  it('splits exported schema columns on any whitespace', async () => {
    await openDb('tabbed');
    await sqlite.execute({
      database: 'tabbed',
      statements:
        'CREATE TABLE tabbed (id\tINTEGER PRIMARY KEY NOT NULL,\r\n  name\t\tTEXT,\r\n  CONSTRAINT\tuq_name UNIQUE (name))',
    });
    const schema = (await sqlite.exportToJson({ database: 'tabbed' })).export?.tables[0].schema;
    expect(schema).toEqual([
      { column: 'id', value: 'INTEGER PRIMARY KEY NOT NULL' },
      { column: 'name', value: 'TEXT' },
      { constraint: 'uq_name', value: 'UNIQUE (name)' },
    ]);
  });
});

describe('JSON validation', () => {
  const base = JSON.parse(basicJson);

  it.each([
    ['an encrypted database', { ...base, encrypted: true }],
    ['an unknown top-level key', { ...base, extra: 1 }],
    ['a non-integer version', { ...base, version: 1.5 }],
    ['a row with the wrong number of values', { ...base, tables: [{ ...base.tables[0], values: [[1, 'Alice']] }] }],
    [
      'an index mode other than UNIQUE',
      { ...base, tables: [{ ...base.tables[0], indexes: [{ name: 'i', value: 'name', mode: 'X' }] }] },
    ],
    [
      'a schema column with an unknown key',
      { ...base, tables: [{ ...base.tables[0], schema: [{ column: 'id', value: 'INTEGER', primarykey: 'id' }] }] },
    ],
  ])('rejects %s', async (_, json) => {
    expect(await sqlite.isJsonValid({ jsonstring: JSON.stringify(json) })).toEqual({ result: false });
  });

  it('accepts encrypted false and mode full', async () => {
    const json = { ...base, encrypted: false, mode: 'full' };
    expect(await sqlite.isJsonValid({ jsonstring: JSON.stringify(json) })).toEqual({ result: true });
  });
});

describe('JSON import rules', () => {
  const v1: JsonSQLite = JSON.parse(basicJson);
  const asImport = (json: object) => ({ jsonstring: JSON.stringify(json) });

  it('rejects a version lower than the stored one', async () => {
    await sqlite.importFromJson(asImport({ ...v1, version: 2 }));
    await expect(sqlite.importFromJson(asImport({ ...v1, version: 1, overwrite: false }))).rejects.toThrow(
      'Cannot import a version lower than 2',
    );
  });

  it('skips an import of the same version without overwrite', async () => {
    await sqlite.importFromJson(asImport(v1));
    const sameVersion = { ...v1, overwrite: false, tables: [{ ...v1.tables[0], values: [[3, 'Cy', 50]] }] };
    expect(await sqlite.importFromJson(asImport(sameVersion))).toEqual({ changes: { changes: 0 } });
    await openDb('testjson_file');
    expect(await count('testjson_file', 'users')).toBe(2);
  });

  it('replaces the whole database with overwrite', async () => {
    await sqlite.importFromJson(asImport(v1));
    const replaced = { ...v1, tables: [{ ...v1.tables[0], values: [[3, 'Cy', 50]] }] };
    await sqlite.importFromJson(asImport(replaced));
    await openDb('testjson_file');
    const res = await sqlite.query({ database: 'testjson_file', statement: 'SELECT name FROM users' });
    expect(res.values).toEqual([{ name: 'Cy' }]);
  });

  it('round-trips indexes, triggers, views, foreign keys and blobs', async () => {
    await openDb('source');
    await sqlite.execute({
      database: 'source',
      statements: `${schemaSql}
        CREATE UNIQUE INDEX IF NOT EXISTS idx_owner_name ON owners (name);
        CREATE TRIGGER IF NOT EXISTS boats_rename AFTER UPDATE ON boats FOR EACH ROW WHEN NEW.name IS NULL
          BEGIN UPDATE boats SET name = 'unnamed' WHERE id = NEW.id; END;
        CREATE VIEW IF NOT EXISTS boat_owners AS SELECT b.name AS boat, o.name AS owner FROM boats b JOIN owners o ON o.id = b.owner_id;
        INSERT INTO owners (id, name) VALUES (1, 'Anna');`,
    });
    await sqlite.run({
      database: 'source',
      statement: 'INSERT INTO boats (id, owner_id, name, photo) VALUES (?, ?, ?, ?)',
      values: [1, 1, 'Vega', [1, 2, 3]],
    });
    const exported = (await sqlite.exportToJson({ database: 'source' })).export as JsonSQLite;
    expect(await sqlite.isJsonValid({ jsonstring: JSON.stringify(exported) })).toEqual({ result: true });

    await sqlite.importFromJson(asImport({ ...exported, database: 'copy', overwrite: true }));
    await openDb('copy');
    const copy = (await sqlite.exportToJson({ database: 'copy' })).export as JsonSQLite;
    expect(copy.tables).toEqual(exported.tables);
    expect(copy.views).toEqual(exported.views);
    expect(await sqlite.query({ database: 'copy', statement: 'SELECT * FROM boat_owners' })).toEqual({
      values: [{ boat: 'Vega', owner: 'Anna' }],
    });
    // the trigger and the foreign key came across too
    await sqlite.run({ database: 'copy', statement: 'UPDATE boats SET name = NULL WHERE id = 1' });
    expect((await sqlite.query({ database: 'copy', statement: 'SELECT name FROM boats' })).values).toEqual([
      { name: 'unnamed' },
    ]);
    await expect(
      sqlite.run({ database: 'copy', statement: 'INSERT INTO boats (id, owner_id) VALUES (2, 99)' }),
    ).rejects.toThrow('FOREIGN KEY constraint failed');
  });
});

describe('connections', () => {
  it('needs initWebStore first', async () => {
    const fresh = new CapacitorSQLiteWeb();
    await fresh.createConnection({ database: 'db' });
    await expect(fresh.open({ database: 'db' })).rejects.toThrow('initWebStore');
  });

  it('refuses a second connection to the same database, with or without .db', async () => {
    await sqlite.createConnection({ database: 'db' });
    await expect(sqlite.createConnection({ database: 'db.db' })).rejects.toThrow(
      'CreateConnection: Connection db already exists',
    );
  });

  it('reports a missing or closed connection like the native plugins', async () => {
    await expect(sqlite.query({ database: 'nope', statement: 'SELECT 1' })).rejects.toThrow(
      'Query: No available connection for database nope',
    );
    await sqlite.createConnection({ database: 'db' });
    expect(await sqlite.isDBOpen({ database: 'db' })).toEqual({ result: false });
    await expect(sqlite.close({ database: 'db' })).rejects.toThrow('Close: database db not opened');
    await sqlite.open({ database: 'db' });
    expect(await sqlite.isDBOpen({ database: 'db' })).toEqual({ result: true });
  });

  it('keeps matching connections and drops the ones JS no longer knows', async () => {
    await openDb('a');
    await openDb('b');
    expect(await sqlite.checkConnectionsConsistency({ dbNames: ['a', 'b'] })).toEqual({ result: true });
    expect(await sqlite.checkConnectionsConsistency({ dbNames: ['a'] })).toEqual({ result: true });
    await expect(sqlite.isDBOpen({ database: 'b' })).rejects.toThrow('No available connection');
    expect(await sqlite.isDBOpen({ database: 'a' })).toEqual({ result: true });
  });

  it('closes everything when JS knows connections the plugin does not', async () => {
    await openDb('a');
    expect(await sqlite.checkConnectionsConsistency({ dbNames: ['a', 'b'] })).toEqual({ result: false });
    await expect(sqlite.isDBOpen({ database: 'a' })).rejects.toThrow('No available connection');
  });
});

describe('writes', () => {
  beforeEach(async () => {
    await openDb('db');
    await sqlite.execute({ database: 'db', statements: schemaSql });
  });

  it('returns changes and lastId', async () => {
    expect(
      await sqlite.run({
        database: 'db',
        statement: 'INSERT INTO owners (id, name) VALUES (?, ?)',
        values: [7, 'Anna'],
      }),
    ).toEqual({
      changes: { changes: 1, lastId: 7 },
    });
    const res = await sqlite.executeSet({
      database: 'db',
      set: [
        { statement: 'INSERT INTO owners (id, name) VALUES (?, ?)', values: [8, 'Bo'] },
        { statement: 'UPDATE owners SET name = ? WHERE id = ?', values: ['Anna B', 7] },
      ],
    });
    expect(res).toEqual({ changes: { changes: 2, lastId: 8 } });
    expect(await sqlite.execute({ database: 'db', statements: 'DELETE FROM owners;' })).toEqual({
      changes: { changes: 2 },
    });
  });

  it('rolls back a failing set inside a transaction', async () => {
    const set = [
      { statement: 'INSERT INTO owners (id, name) VALUES (?, ?)', values: [1, 'Anna'] },
      { statement: 'INSERT INTO owners (id, name) VALUES (?, ?)', values: [1, 'Duplicate'] },
    ];
    await expect(sqlite.executeSet({ database: 'db', set })).rejects.toThrow('ExecuteSet: UNIQUE constraint failed');
    expect(await count('db', 'owners')).toBe(0);
  });

  it('keeps the statements before the failure without a transaction', async () => {
    const set = [
      { statement: 'INSERT INTO owners (id, name) VALUES (?, ?)', values: [1, 'Anna'] },
      { statement: 'INSERT INTO owners (id, name) VALUES (?, ?)', values: [1, 'Duplicate'] },
    ];
    await expect(sqlite.executeSet({ database: 'db', set, transaction: false })).rejects.toThrow();
    expect(await count('db', 'owners')).toBe(1);
  });

  it('enforces foreign keys, also after a write has been saved', async () => {
    await sqlite.run({ database: 'db', statement: 'INSERT INTO owners (id, name) VALUES (1, ?)', values: ['Anna'] });
    // saving exports the database, which resets the pragmas
    await sqlite.saveToStore({ database: 'db' });
    await expect(
      sqlite.run({ database: 'db', statement: 'INSERT INTO boats (id, owner_id) VALUES (1, 99)' }),
    ).rejects.toThrow('FOREIGN KEY constraint failed');
    await sqlite.run({ database: 'db', statement: 'INSERT INTO boats (id, owner_id) VALUES (1, 1)' });
    await sqlite.run({ database: 'db', statement: 'DELETE FROM owners WHERE id = 1' });
    expect(await count('db', 'boats')).toBe(0);
  });

  it('binds undefined as NULL and returns blobs as number arrays', async () => {
    await sqlite.run({ database: 'db', statement: 'INSERT INTO owners (id, name) VALUES (1, ?)', values: ['Anna'] });
    await sqlite.run({
      database: 'db',
      statement: 'INSERT INTO boats (id, owner_id, name, photo) VALUES (?, ?, ?, ?)',
      values: [1, 1, undefined, [255, 0, 7]],
    });
    expect((await sqlite.query({ database: 'db', statement: 'SELECT name, photo FROM boats' })).values).toEqual([
      { name: null, photo: [255, 0, 7] },
    ]);
  });
});

describe('web store', () => {
  it('keeps every write without an explicit save', async () => {
    await openDb('db');
    await sqlite.execute({ database: 'db', statements: schemaSql });
    await sqlite.run({ database: 'db', statement: "INSERT INTO owners (id, name) VALUES (1, 'Anna')" });

    // a new plugin instance on the same IndexedDB, like reloading the page
    sqlite = new CapacitorSQLiteWeb();
    await sqlite.initWebStore();
    expect(await sqlite.isDatabase({ database: 'db' })).toEqual({ result: true });
    await openDb('db');
    expect(await count('db', 'owners')).toBe(1);
  });

  it('opens a database jeep-sqlite saved', async () => {
    const SQL = await initSqlJs();
    const legacy = new SQL.Database();
    legacy.exec(
      "CREATE TABLE notes (id INTEGER PRIMARY KEY, body TEXT); INSERT INTO notes VALUES (1, 'saved by jeep');",
    );
    // jeep-sqlite kept files in localforage's "databases" store of the "jeepSqliteStore" IndexedDB
    await new Promise<void>((resolve, reject) => {
      const req = indexedDB.open('jeepSqliteStore', 1);
      req.onupgradeneeded = () => req.result.createObjectStore('databases');
      req.onsuccess = () => {
        const tx = req.result.transaction('databases', 'readwrite');
        tx.objectStore('databases').put(legacy.export(), 'legacySQLite.db');
        tx.oncomplete = () => resolve();
        tx.onerror = () => reject(tx.error);
      };
    });

    sqlite = new CapacitorSQLiteWeb();
    await sqlite.initWebStore();
    await openDb('legacy');
    expect((await sqlite.query({ database: 'legacy', statement: 'SELECT body FROM notes' })).values).toEqual([
      { body: 'saved by jeep' },
    ]);
  });

  it('does not count an opened but empty database', async () => {
    await openDb('empty');
    expect(await sqlite.isDatabase({ database: 'empty' })).toEqual({ result: false });
  });
});
