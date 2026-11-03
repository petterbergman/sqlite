<h2 align="center">JSON Import/Export DOCUMENTATION</h2>
<p align="center"><strong><code>@capacitor-community/sqlite</code></strong> (minimal fork)</p>

## Index

- [Methods](#methods)
  - [importFromJson](#importfromjson)
  - [exportToJson](#exporttojson)
  - [isJsonValid](#isjsonvalid)
- [JSON Object](#json-object)
- [Examples](#examples)
  - [Tables, indexes and data](#tables-indexes-and-data)
  - [Views](#views)
  - [Composite keys](#composite-keys)

## Methods

This fork only supports **full** import and export: the JSON object always describes the whole database. Upstream's partial mode, sync table, `sql_deleted` soft deletes and encrypted imports have been removed, so the `mode` and `encrypted` keys no longer exist.

### importFromJson

Creates or replaces a database from a JSON object. The connection to the database must be closed before calling it.

What happens depends on `version` and `overwrite`:

- `overwrite: true`: the database file is deleted and rebuilt from the JSON, whatever its version.
- `overwrite` false or missing:
  - the database doesn't exist yet: it is created.
  - the JSON `version` is **higher** than the database's: all existing tables, indexes, triggers and views are dropped, then the JSON is imported.
  - the JSON `version` is **equal**: nothing is done and `changes` is `0`.
  - the JSON `version` is **lower**: the import fails with `Cannot import a version lower than …`.

Foreign keys are turned off while the old schema is dropped and back on afterwards.

The import runs as separate transactions: one for the schema (tables, indexes, triggers), one for the rows and one for the views. Rows are written with plain `INSERT` statements, so each row in `values` must list a value for every column, in schema order.

### exportToJson

Exports the whole open database (schema, indexes, triggers, rows and views) to a JSON object in the same format, which can be fed back to `importFromJson`.

### isJsonValid

Checks that a JSON string matches the expected format, without touching any database. Use it before an import or to validate an export.

## JSON Object

```ts
interface JsonSQLite {
  database: string;
  version: number;
  overwrite?: boolean; // default false
  tables: JsonTable[];
  views?: JsonView[];
}

interface JsonTable {
  name: string;
  schema?: JsonColumn[];
  indexes?: JsonIndex[];
  triggers?: JsonTrigger[];
  values?: any[][];
}

interface JsonColumn {
  column?: string;     // column name
  foreignkey?: string; // FOREIGN KEY (<foreignkey>) <value>
  constraint?: string; // CONSTRAINT <constraint> <value>
  value: string;       // type and column constraints
}

interface JsonIndex {
  name: string;
  value: string; // "email", "email ASC", "email ASC, name DESC"
  mode?: string; // "UNIQUE"
}

interface JsonTrigger {
  name: string;
  timeevent: string; // e.g. "AFTER UPDATE"
  condition?: string;
  logic: string;
}

interface JsonView {
  name: string;
  value: string; // the SELECT statement
}
```

Each `JsonColumn` sets exactly one of `column`, `foreignkey` or `constraint`.

## Examples

### Tables, indexes and data

```ts
import { CapacitorSQLite, SQLiteConnection } from '@capacitor-community/sqlite';

const sqlite = new SQLiteConnection(CapacitorSQLite);

const dataToImport = {
  database: 'db-from-json',
  version: 1,
  overwrite: true,
  tables: [
    {
      name: 'users',
      schema: [
        { column: 'id', value: 'INTEGER PRIMARY KEY NOT NULL' },
        { column: 'email', value: 'TEXT UNIQUE NOT NULL' },
        { column: 'name', value: 'TEXT' },
        { column: 'age', value: 'INTEGER' },
      ],
      indexes: [
        { name: 'index_user_on_name', value: 'name' },
        { name: 'index_user_on_email_name', value: 'email ASC, name', mode: 'UNIQUE' },
      ],
      values: [
        [1, 'whiteley@example.com', 'Whiteley', 30],
        [2, 'jones@example.com', 'Jones', 44],
      ],
    },
    {
      name: 'messages',
      schema: [
        { column: 'id', value: 'INTEGER PRIMARY KEY NOT NULL' },
        { column: 'userid', value: 'INTEGER' },
        { column: 'title', value: 'TEXT NOT NULL' },
        { column: 'body', value: 'TEXT NOT NULL' },
        { foreignkey: 'userid', value: 'REFERENCES users(id) ON DELETE CASCADE' },
      ],
      indexes: [{ name: 'index_messages_on_title', value: 'title' }],
      values: [
        [1, 1, 'test post 1', 'content test post 1'],
        [2, 2, 'test post 2', 'content test post 2'],
      ],
    },
  ],
};

const jsonstring = JSON.stringify(dataToImport);
const { result } = await sqlite.isJsonValid(jsonstring);
if (result) {
  const { changes } = await sqlite.importFromJson(jsonstring);
}

// later, with an open connection
const db = await sqlite.createConnection('db-from-json', 1);
await db.open();
const { export: exported } = await db.exportToJson();
```

### Views

```ts
const dataToImport = {
  database: 'db-views',
  version: 1,
  tables: [
    {
      name: 'departments',
      schema: [
        { column: 'id', value: 'INTEGER PRIMARY KEY AUTOINCREMENT' },
        { column: 'name', value: 'TEXT NOT NULL' },
      ],
      values: [
        [1, 'Admin'],
        [2, 'Sales'],
      ],
    },
    {
      name: 'employees',
      schema: [
        { column: 'id', value: 'INTEGER PRIMARY KEY AUTOINCREMENT' },
        { column: 'first_name', value: 'TEXT' },
        { column: 'last_name', value: 'TEXT' },
        { column: 'dept_id', value: 'INTEGER' },
      ],
      values: [
        [1, 'John', 'Brown', 1],
        [2, 'Sally', 'Brown', 2],
      ],
    },
  ],
  views: [
    {
      name: 'SalesTeam',
      value: "SELECT id, first_name, last_name FROM employees WHERE dept_id IN (SELECT id FROM departments WHERE name = 'Sales')",
    },
  ],
};
```

### Composite keys

```ts
const schemaToImport = {
  database: 'db-composite',
  version: 1,
  tables: [
    {
      name: 'album',
      schema: [
        { column: 'albumartist', value: 'TEXT NOT NULL' },
        { column: 'albumname', value: 'TEXT NOT NULL' },
        { column: 'albumcover', value: 'BLOB' },
        { constraint: 'PK_albumartist_albumname', value: 'PRIMARY KEY (albumartist, albumname)' },
      ],
    },
    {
      name: 'song',
      schema: [
        { column: 'songid', value: 'INTEGER PRIMARY KEY NOT NULL' },
        { column: 'songartist', value: 'TEXT NOT NULL' },
        { column: 'songalbum', value: 'TEXT NOT NULL' },
        { column: 'songname', value: 'TEXT NOT NULL' },
        { foreignkey: 'songartist, songalbum', value: 'REFERENCES album(albumartist, albumname)' },
      ],
    },
  ],
};
```
