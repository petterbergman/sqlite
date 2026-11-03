<h2 align="center">API PLUGIN DOCUMENTATION</h2>
<p align="center"><strong><code>@capacitor-community/sqlite</code></strong> (minimal fork)</p>

## Plugin Wrappers

Most apps should use the two connection wrappers rather than calling the plugin directly:

- [Connection wrapper](APIConnection.md)
- [DB connection wrapper](APIDBConnection.md)

## SQLite Commands Within the Plugin

- Data Definition Language (`CREATE`, `ALTER`, `DROP`): `execute`
- Transaction control (`BEGIN TRANSACTION`, `COMMIT`, `ROLLBACK`): `execute`, with its own `transaction` flag set to `false`
- Data Manipulation Language (`INSERT`, `UPDATE`, `DELETE`, `REPLACE`): `run` when there are bind values, `executeSet` for a batch, either `execute` or `run` otherwise
- Queries (`SELECT`): `query`
- `PRAGMA`: `execute`

`execute`, `run` and `executeSet` wrap their statements in a transaction unless `transaction: false` is passed.

## Databases Location

The plugin adds the suffix `SQLite` and the extension `.db` to the database name (`fooDB` → `fooDBSQLite.db`). A trailing `.db` in the given name is removed first (`foo.db` → `fooSQLite.db`).

### Android

- `data/data/YOUR_PACKAGE/databases`

### iOS

- the `Documents` folder of your application, or
- the folder set by `iosDatabaseLocation` in `capacitor.config.ts`. Databases there are not visible in Files/iTunes and not backed up to iCloud.

  ```ts
  const config: CapacitorConfig = {
    plugins: {
      CapacitorSQLite: {
        iosDatabaseLocation: 'Library/CapacitorDatabase',
      },
    },
  };
  ```

### Web

- IndexedDB, in the `databases` object store of the `jeepSqliteStore` database. The in-memory sql.js database is written to the store after every write, on `open`, `saveToStore`, `close` and `closeConnection`.

## Running multiple statements

Some users have seen a single `execute` call containing several `UPDATE` statements apply only part of them on Android and iOS, while the web build applied all of them ([upstream #393](https://github.com/capacitor-community/sqlite/issues/393)). If that happens, run the statements one at a time, awaiting each, or use `executeSet`.

## Error Return values

- Every method rejects with an error message on failure.


## Methods Index

<docgen-index>

* [`initWebStore()`](#initwebstore)
* [`saveToStore(...)`](#savetostore)
* [`createConnection(...)`](#createconnection)
* [`closeConnection(...)`](#closeconnection)
* [`open(...)`](#open)
* [`close(...)`](#close)
* [`execute(...)`](#execute)
* [`executeSet(...)`](#executeset)
* [`run(...)`](#run)
* [`query(...)`](#query)
* [`isDBOpen(...)`](#isdbopen)
* [`isDatabase(...)`](#isdatabase)
* [`isJsonValid(...)`](#isjsonvalid)
* [`importFromJson(...)`](#importfromjson)
* [`exportToJson(...)`](#exporttojson)
* [`checkConnectionsConsistency(...)`](#checkconnectionsconsistency)
* [Interfaces](#interfaces)

</docgen-index>

## API Plugin

<docgen-api>
<!--Update the source file JSDoc comments and rerun docgen to update the docs below-->

CapacitorSQLitePlugin Interface

### initWebStore()

```typescript
initWebStore() => Promise<void>
```

Initialize the web store

**Since:** 3.2.3-1

--------------------


### saveToStore(...)

```typescript
saveToStore(options: capSQLiteOptions) => Promise<void>
```

Save database to  the web store

| Param         | Type                                                          | Description                                        |
| ------------- | ------------------------------------------------------------- | -------------------------------------------------- |
| **`options`** | <code><a href="#capsqliteoptions">capSQLiteOptions</a></code> | : <a href="#capsqliteoptions">capSQLiteOptions</a> |

**Since:** 3.2.3-1

--------------------


### createConnection(...)

```typescript
createConnection(options: capConnectionOptions) => Promise<void>
```

create a database connection

| Param         | Type                                                                  | Description                                              |
| ------------- | --------------------------------------------------------------------- | -------------------------------------------------------- |
| **`options`** | <code><a href="#capconnectionoptions">capConnectionOptions</a></code> | <a href="#capconnectionoptions">capConnectionOptions</a> |

**Since:** 2.9.0 refactor

--------------------


### closeConnection(...)

```typescript
closeConnection(options: capSQLiteOptions) => Promise<void>
```

close a database connection

| Param         | Type                                                          | Description                                      |
| ------------- | ------------------------------------------------------------- | ------------------------------------------------ |
| **`options`** | <code><a href="#capsqliteoptions">capSQLiteOptions</a></code> | <a href="#capsqliteoptions">capSQLiteOptions</a> |

**Since:** 2.9.0 refactor

--------------------


### open(...)

```typescript
open(options: capSQLiteOptions) => Promise<void>
```

Opens a SQLite database.
Attention: This re-opens a database if it's already open!

| Param         | Type                                                          | Description                                        |
| ------------- | ------------------------------------------------------------- | -------------------------------------------------- |
| **`options`** | <code><a href="#capsqliteoptions">capSQLiteOptions</a></code> | : <a href="#capsqliteoptions">capSQLiteOptions</a> |

**Since:** 0.0.1

--------------------


### close(...)

```typescript
close(options: capSQLiteOptions) => Promise<void>
```

Close a SQLite database

| Param         | Type                                                          | Description                                        |
| ------------- | ------------------------------------------------------------- | -------------------------------------------------- |
| **`options`** | <code><a href="#capsqliteoptions">capSQLiteOptions</a></code> | : <a href="#capsqliteoptions">capSQLiteOptions</a> |

**Since:** 0.0.1

--------------------


### execute(...)

```typescript
execute(options: capSQLiteExecuteOptions) => Promise<capSQLiteChanges>
```

Execute a Batch of Raw Statements as String

| Param         | Type                                                                        | Description                                                      |
| ------------- | --------------------------------------------------------------------------- | ---------------------------------------------------------------- |
| **`options`** | <code><a href="#capsqliteexecuteoptions">capSQLiteExecuteOptions</a></code> | : <a href="#capsqliteexecuteoptions">capSQLiteExecuteOptions</a> |

**Returns:** <code>Promise&lt;<a href="#capsqlitechanges">capSQLiteChanges</a>&gt;</code>

**Since:** 0.0.1

--------------------


### executeSet(...)

```typescript
executeSet(options: capSQLiteSetOptions) => Promise<capSQLiteChanges>
```

Execute a Set of Raw Statements as Array of CapSQLiteSet

| Param         | Type                                                                | Description                                              |
| ------------- | ------------------------------------------------------------------- | -------------------------------------------------------- |
| **`options`** | <code><a href="#capsqlitesetoptions">capSQLiteSetOptions</a></code> | : <a href="#capsqlitesetoptions">capSQLiteSetOptions</a> |

**Returns:** <code>Promise&lt;<a href="#capsqlitechanges">capSQLiteChanges</a>&gt;</code>

**Since:** 2.2.0-2

--------------------


### run(...)

```typescript
run(options: capSQLiteRunOptions) => Promise<capSQLiteChanges>
```

Execute a Single Statement

| Param         | Type                                                                | Description                                              |
| ------------- | ------------------------------------------------------------------- | -------------------------------------------------------- |
| **`options`** | <code><a href="#capsqliterunoptions">capSQLiteRunOptions</a></code> | : <a href="#capsqliterunoptions">capSQLiteRunOptions</a> |

**Returns:** <code>Promise&lt;<a href="#capsqlitechanges">capSQLiteChanges</a>&gt;</code>

**Since:** 0.0.1

--------------------


### query(...)

```typescript
query(options: capSQLiteQueryOptions) => Promise<capSQLiteValues>
```

Query a Single Statement

| Param         | Type                                                                    | Description                                                  |
| ------------- | ----------------------------------------------------------------------- | ------------------------------------------------------------ |
| **`options`** | <code><a href="#capsqlitequeryoptions">capSQLiteQueryOptions</a></code> | : <a href="#capsqlitequeryoptions">capSQLiteQueryOptions</a> |

**Returns:** <code>Promise&lt;<a href="#capsqlitevalues">capSQLiteValues</a>&gt;</code>

**Since:** 0.0.1

--------------------


### isDBOpen(...)

```typescript
isDBOpen(options: capSQLiteOptions) => Promise<capSQLiteResult>
```

Check if a SQLite database is opened

| Param         | Type                                                          | Description                                        |
| ------------- | ------------------------------------------------------------- | -------------------------------------------------- |
| **`options`** | <code><a href="#capsqliteoptions">capSQLiteOptions</a></code> | : <a href="#capsqliteoptions">capSQLiteOptions</a> |

**Returns:** <code>Promise&lt;<a href="#capsqliteresult">capSQLiteResult</a>&gt;</code>

**Since:** 3.0.0-beta.5

--------------------


### isDatabase(...)

```typescript
isDatabase(options: capSQLiteOptions) => Promise<capSQLiteResult>
```

Check if a SQLite database exists without connection

| Param         | Type                                                          | Description                                        |
| ------------- | ------------------------------------------------------------- | -------------------------------------------------- |
| **`options`** | <code><a href="#capsqliteoptions">capSQLiteOptions</a></code> | : <a href="#capsqliteoptions">capSQLiteOptions</a> |

**Returns:** <code>Promise&lt;<a href="#capsqliteresult">capSQLiteResult</a>&gt;</code>

**Since:** 3.0.0-beta.5

--------------------


### isJsonValid(...)

```typescript
isJsonValid(options: capSQLiteImportOptions) => Promise<capSQLiteResult>
```

Is Json Object Valid

| Param         | Type                                                                      | Description                                                    |
| ------------- | ------------------------------------------------------------------------- | -------------------------------------------------------------- |
| **`options`** | <code><a href="#capsqliteimportoptions">capSQLiteImportOptions</a></code> | : <a href="#capsqliteimportoptions">capSQLiteImportOptions</a> |

**Returns:** <code>Promise&lt;<a href="#capsqliteresult">capSQLiteResult</a>&gt;</code>

**Since:** 2.0.1-1

--------------------


### importFromJson(...)

```typescript
importFromJson(options: capSQLiteImportOptions) => Promise<capSQLiteChanges>
```

Import from Json Object

| Param         | Type                                                                      | Description                                                    |
| ------------- | ------------------------------------------------------------------------- | -------------------------------------------------------------- |
| **`options`** | <code><a href="#capsqliteimportoptions">capSQLiteImportOptions</a></code> | : <a href="#capsqliteimportoptions">capSQLiteImportOptions</a> |

**Returns:** <code>Promise&lt;<a href="#capsqlitechanges">capSQLiteChanges</a>&gt;</code>

**Since:** 2.0.0-3

--------------------


### exportToJson(...)

```typescript
exportToJson(options: capSQLiteOptions) => Promise<capSQLiteJson>
```

Export the whole database to a Json Object

| Param         | Type                                                          | Description                                        |
| ------------- | ------------------------------------------------------------- | -------------------------------------------------- |
| **`options`** | <code><a href="#capsqliteoptions">capSQLiteOptions</a></code> | : <a href="#capsqliteoptions">capSQLiteOptions</a> |

**Returns:** <code>Promise&lt;<a href="#capsqlitejson">capSQLiteJson</a>&gt;</code>

**Since:** 2.0.1-1

--------------------


### checkConnectionsConsistency(...)

```typescript
checkConnectionsConsistency(options: capAllConnectionsOptions) => Promise<capSQLiteResult>
```

Check Connection Consistency JS &lt;=&gt; Native
return true : consistency, connections are opened
return false : no consistency, connections are closed

| Param         | Type                                                                          | Description                                                        |
| ------------- | ----------------------------------------------------------------------------- | ------------------------------------------------------------------ |
| **`options`** | <code><a href="#capallconnectionsoptions">capAllConnectionsOptions</a></code> | : <a href="#capallconnectionsoptions">capAllConnectionsOptions</a> |

**Returns:** <code>Promise&lt;<a href="#capsqliteresult">capSQLiteResult</a>&gt;</code>

**Since:** 3.0.0-beta.11

--------------------


### Interfaces


#### capSQLiteOptions

| Prop           | Type                | Description       |
| -------------- | ------------------- | ----------------- |
| **`database`** | <code>string</code> | The database name |


#### capConnectionOptions

| Prop           | Type                | Description          |
| -------------- | ------------------- | -------------------- |
| **`database`** | <code>string</code> | The database name    |
| **`version`**  | <code>number</code> | The database version |


#### capSQLiteChanges

| Prop          | Type                                        | Description                               |
| ------------- | ------------------------------------------- | ----------------------------------------- |
| **`changes`** | <code><a href="#changes">Changes</a></code> | a returned <a href="#changes">Changes</a> |


#### Changes

| Prop          | Type                | Description                                          |
| ------------- | ------------------- | ---------------------------------------------------- |
| **`changes`** | <code>number</code> | the number of changes from an execute or run command |
| **`lastId`**  | <code>number</code> | the lastId created from a run command                |
| **`values`**  | <code>any[]</code>  | values when RETURNING                                |


#### capSQLiteExecuteOptions

| Prop              | Type                 | Description                                         | Since         |
| ----------------- | -------------------- | --------------------------------------------------- | ------------- |
| **`database`**    | <code>string</code>  | The database name                                   |               |
| **`statements`**  | <code>string</code>  | The batch of raw SQL statements as string           |               |
| **`transaction`** | <code>boolean</code> | Enable / Disable transactions default Enable (true) | 3.0.0-beta.10 |


#### capSQLiteSetOptions

| Prop              | Type                        | Description                                               | Since         |
| ----------------- | --------------------------- | --------------------------------------------------------- | ------------- |
| **`database`**    | <code>string</code>         | The database name                                         |               |
| **`set`**         | <code>capSQLiteSet[]</code> | The batch of raw SQL statements as Array of capSQLLiteSet |               |
| **`transaction`** | <code>boolean</code>        | Enable / Disable transactions default Enable (true)       | 3.0.0-beta.10 |


#### capSQLiteSet

| Prop            | Type                | Description                      |
| --------------- | ------------------- | -------------------------------- |
| **`statement`** | <code>string</code> | A statement                      |
| **`values`**    | <code>any[]</code>  | the data values list as an Array |


#### capSQLiteRunOptions

| Prop              | Type                 | Description                                         | Since         |
| ----------------- | -------------------- | --------------------------------------------------- | ------------- |
| **`database`**    | <code>string</code>  | The database name                                   |               |
| **`statement`**   | <code>string</code>  | A statement                                         |               |
| **`values`**      | <code>any[]</code>   | A set of values for a statement                     |               |
| **`transaction`** | <code>boolean</code> | Enable / Disable transactions default Enable (true) | 3.0.0-beta.10 |


#### capSQLiteValues

| Prop         | Type               | Description                                                                              |
| ------------ | ------------------ | ---------------------------------------------------------------------------------------- |
| **`values`** | <code>any[]</code> | the data values list as an Array iOS the first row is the returned ios_columns name list |


#### capSQLiteQueryOptions

| Prop            | Type                | Description                                     | Since         |
| --------------- | ------------------- | ----------------------------------------------- | ------------- |
| **`database`**  | <code>string</code> | The database name                               |               |
| **`statement`** | <code>string</code> | A statement                                     |               |
| **`values`**    | <code>any[]</code>  | A set of values for a statement Change to any[] | 3.0.0-beta.11 |


#### capSQLiteResult

| Prop         | Type                 | Description                                   |
| ------------ | -------------------- | --------------------------------------------- |
| **`result`** | <code>boolean</code> | result set to true when successful else false |


#### capSQLiteImportOptions

| Prop             | Type                | Description                   |
| ---------------- | ------------------- | ----------------------------- |
| **`jsonstring`** | <code>string</code> | Set the JSON object to import |


#### capSQLiteJson

| Prop         | Type                                              | Description           |
| ------------ | ------------------------------------------------- | --------------------- |
| **`export`** | <code><a href="#jsonsqlite">JsonSQLite</a></code> | an export JSON object |


#### JsonSQLite

| Prop            | Type                     | Description                                           |
| --------------- | ------------------------ | ----------------------------------------------------- |
| **`database`**  | <code>string</code>      | The database name                                     |
| **`version`**   | <code>number</code>      | The database version                                  |
| **`overwrite`** | <code>boolean</code>     | Delete the database prior to import (default false)   |
| **`tables`**    | <code>JsonTable[]</code> | * Array of Table (<a href="#jsontable">JsonTable</a>) |
| **`views`**     | <code>JsonView[]</code>  | * Array of View (<a href="#jsonview">JsonView</a>)    |


#### JsonTable

| Prop           | Type                       | Description                                                 |
| -------------- | -------------------------- | ----------------------------------------------------------- |
| **`name`**     | <code>string</code>        | The database name                                           |
| **`schema`**   | <code>JsonColumn[]</code>  | * Array of Schema (<a href="#jsoncolumn">JsonColumn</a>)    |
| **`indexes`**  | <code>JsonIndex[]</code>   | * Array of Index (<a href="#jsonindex">JsonIndex</a>)       |
| **`triggers`** | <code>JsonTrigger[]</code> | * Array of Trigger (<a href="#jsontrigger">JsonTrigger</a>) |
| **`values`**   | <code>any[][]</code>       | * Array of Table data                                       |


#### JsonColumn

| Prop             | Type                | Description                         |
| ---------------- | ------------------- | ----------------------------------- |
| **`column`**     | <code>string</code> | The column name                     |
| **`value`**      | <code>string</code> | The column data (type, unique, ...) |
| **`foreignkey`** | <code>string</code> | The column foreign key constraints  |
| **`constraint`** | <code>string</code> | the column constraint               |


#### JsonIndex

| Prop        | Type                | Description                                                                                                             |
| ----------- | ------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| **`name`**  | <code>string</code> | The index name                                                                                                          |
| **`value`** | <code>string</code> | The value of the index can have the following formats: email email ASC email, MobileNumber email ASC, MobileNumber DESC |
| **`mode`**  | <code>string</code> | the mode (Optional) UNIQUE                                                                                              |


#### JsonTrigger

| Prop            | Type                | Description                  |
| --------------- | ------------------- | ---------------------------- |
| **`name`**      | <code>string</code> | The trigger name             |
| **`timeevent`** | <code>string</code> | The trigger time event fired |
| **`condition`** | <code>string</code> | The trigger condition        |
| **`logic`**     | <code>string</code> | The logic of the trigger     |


#### JsonView

| Prop        | Type                | Description               |
| ----------- | ------------------- | ------------------------- |
| **`name`**  | <code>string</code> | The view name             |
| **`value`** | <code>string</code> | The view create statement |


#### capAllConnectionsOptions

| Prop          | Type                  | Description                   | Since         |
| ------------- | --------------------- | ----------------------------- | ------------- |
| **`dbNames`** | <code>string[]</code> | the dbName of all connections | 3.0.0-beta.10 |

</docgen-api>
