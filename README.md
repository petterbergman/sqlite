<h3 align="center">SQLITE DATABASE (minimal fork)</h3>
<p align="center"><strong><code>@capacitor-community/sqlite</code></strong></p>

<p align="center">
  A minimalist fork of <a href="https://github.com/capacitor-community/sqlite">capacitor-community/sqlite</a>:
  native SQLite for Capacitor on iOS and Android, plus a sql.js web implementation for development and tests, with everything else stripped out.
</p>

## Why this fork

The upstream plugin covers a very wide surface: encryption, biometrics, Electron, partial sync, version upgrades, non-conformed databases, migration helpers and more. This fork keeps only the small core an app actually needs to open a database, run SQL and move data in and out as JSON. The result is roughly 14,000 fewer lines of TypeScript, Swift and Java, fewer native dependencies, and a smaller attack and maintenance surface.

The package name and JavaScript API stay compatible with upstream for the methods that remain, so an app that only uses those can switch without code changes.

## What is kept

| Method                        | Android | iOS | Web |
| :---------------------------- | :-----: | :-: | :-: |
| createConnection              | ✅      | ✅  | ✅  |
| closeConnection               | ✅      | ✅  | ✅  |
| checkConnectionsConsistency   | ✅      | ✅  | ✅  |
| open / close                  | ✅      | ✅  | ✅  |
| execute                       | ✅      | ✅  | ✅  |
| executeSet                    | ✅      | ✅  | ✅  |
| run                           | ✅      | ✅  | ✅  |
| query                         | ✅      | ✅  | ✅  |
| isDBOpen                      | ✅      | ✅  | ✅  |
| isDatabase                    | ✅      | ✅  | ✅  |
| isJsonValid                   | ✅      | ✅  | ✅  |
| importFromJson (full)         | ✅      | ✅  | ✅  |
| exportToJson (full)           | ✅      | ✅  | ✅  |
| initWebStore / saveToStore    | ❌      | ❌  | ✅  |

`execute`, `run` and `executeSet` take an optional `transaction` flag (default `true`) that wraps the call in its own transaction.

The `SQLiteConnection` / `SQLiteDBConnection` wrappers are kept as well (`createConnection`, `retrieveConnection`, `isConnection`, `closeAllConnections`, …).

## What is removed

- Electron platform
- Encryption (SQLCipher), secrets and biometric authentication
- Read-only connections
- Partial JSON sync: `createSyncTable`, `setSyncDate`, `getSyncDate`, `sql_deleted` soft deletes, `deleteExportedRows`
- Database version upgrades (`addUpgradeStatement`)
- `RETURNING` / `returnMode`
- Explicit transaction API (`beginTransaction`, `commitTransaction`, `rollbackTransaction`, `isTransactionActive`)
- Non-conformed databases (`createNCConnection`, …) and Cordova migration helpers
- File helpers: `copyFromAssets`, `getFromHTTPRequest`, `deleteDatabase`, `getDatabaseList`, `getTableList`, `isTableExists`, `getUrl`, `getVersion`, local disk import/export on web
- Progress event listeners
- CocoaPods support (iOS builds through Swift Package Manager only)

If you need any of these, use upstream.

## Install

The fork is not published to npm. Reference a commit tarball from your app's `package.json`:

```json
"@capacitor-community/sqlite": "https://github.com/petterbergman/sqlite/archive/<commit-sha>.tar.gz"
```

Then:

```bash
npm install
npx cap sync
```

For the web platform, copy `sql-wasm-browser.wasm` from `node_modules/sql.js/dist/` into your app's assets folder so it is served at `/assets/sql-wasm-browser.wasm` (`src/assets` for Angular, `public/assets` for Vue/React), and call `initWebStore()` once before creating connections. No custom element is needed.

Bundlers pick sql.js's `browser` export, `sql-wasm-browser.js`, which loads that wasm file and has no Node-only imports, so no `fs` or `path` externals are needed.

## Requirements

- Capacitor 8
- iOS 15+, built with Swift Package Manager
- Android `minSdkVersion` 24, `compileSdkVersion` 36
- Node 22+ to build the plugin

## Configuration

The only option is the iOS database location:

```ts
const config: CapacitorConfig = {
  plugins: {
    CapacitorSQLite: {
      iosDatabaseLocation: 'Library/CapacitorDatabase',
    },
  },
};
```

With it set, databases are kept out of the Documents folder, so they are not visible in Files/iTunes or backed up to iCloud. Without it, they live in Documents.

## Database files

The plugin appends `SQLite.db` to the name you pass (`fooDB` → `fooDBSQLite.db`; a trailing `.db` is stripped first).

- **Android:** `data/data/YOUR_PACKAGE/databases`
- **iOS:** `Documents`, or `iosDatabaseLocation` if set
- **Web:** IndexedDB, in the `databases` object store of the `jeepSqliteStore` database (the layout jeep-sqlite used, so its databases still open). Every write is saved to the store as it happens.

## Usage

```ts
import { CapacitorSQLite, SQLiteConnection } from '@capacitor-community/sqlite';

const sqlite = new SQLiteConnection(CapacitorSQLite);

const db = await sqlite.createConnection('app', 1);
await db.open();

await db.execute(`CREATE TABLE IF NOT EXISTS items (id INTEGER PRIMARY KEY, name TEXT);`);
await db.run('INSERT INTO items (name) VALUES (?)', ['first']);
const { values } = await db.query('SELECT * FROM items');

await sqlite.closeConnection('app');
```

Which method to use:

- DDL (`CREATE`, `ALTER`, `DROP`), `PRAGMA` and statements without bind values: `execute`
- DML with bind values: `run`, or `executeSet` for a batch
- `SELECT`: `query`

## API docs

- [Plugin API](docs/API.md)
- [Connection wrapper](docs/APIConnection.md)
- [DB connection wrapper](docs/APIDBConnection.md)
- [JSON import/export](docs/ImportExportJson.md)
- [Reading and writing blobs](docs/SQLiteBlob.md)

The method sections of the three API pages are generated from `src/definitions.ts` with `npm run docgen`.

## Development

```bash
npm run build        # docgen + tsc + rollup
npm run verify       # build iOS (SPM), Android and web
npm run test         # iOS simulator + Android instrumented tests
npm run lint
```

## Credits

All credit for the original plugin goes to [Jean Pierre Quéau](https://github.com/jepiqueau), who maintained it until version 6.0.0, [Robin Genz](https://github.com/robingenz) and the [upstream contributors](https://github.com/capacitor-community/sqlite#contributors-). This fork is MIT licensed, like upstream.
