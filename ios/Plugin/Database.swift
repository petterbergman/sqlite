//
//  Database.swift
//  Plugin
//
//  Created by  Quéau Jean Pierre on 26/11/2020.
//  Copyright © 2020 Max Lynch. All rights reserved.
//

import Foundation

enum DatabaseError: Error {
    case filePath(message: String)
    case open(message: String)
    case close(message: String)
    case getVersion(message: String)
    case executeSQL(message: String)
    case runSQL(message: String)
    case selectSQL(message: String)
    case deleteDB(message: String)
    case execSet(message: String)
    case createSyncTable(message: String)
    case createSyncDate(message: String)
    case getSyncDate(message: String)
    case exportToJson(message: String)
    case importFromJson(message: String)
    case getTableNames(message: String)
    case deleteExportedRows(message: String)
    case isAvailTrans(message: String)
    case beginTransaction(message: String)
    case commitTransaction(message: String)
    case rollbackTransaction(message: String)
}
// swiftlint:disable file_length
// swiftlint:disable type_body_length
class Database {
    var isOpen: Bool = false
    var dbName: String
    var dbVersion: Int
    var encrypted: Bool
    var isEncryption: Bool
    var mode: String
    var vUpgDict: [Int: [String: Any]]
    var databaseLocation: String
    var account: String
    var path: String = ""
    var mDb: OpaquePointer?
    let globalData: GlobalSQLite = GlobalSQLite()
    let uUpg: UtilsUpgrade = UtilsUpgrade()
    var readOnly: Bool = false
    var ncDB: Bool = false
    var isAvailableTransaction = false

    // MARK: - Init
    init(databaseLocation: String, databaseName: String,
         encrypted: Bool, isEncryption: Bool,
         account: String, mode: String, version: Int, readonly: Bool,
         vUpgDict: [Int: [String: Any]] = [:]
    ) throws {
        self.dbVersion = version
        self.encrypted = encrypted
        self.isEncryption = isEncryption
        self.account = account
        self.dbName = databaseName
        self.mode = mode
        self.vUpgDict = vUpgDict
        self.databaseLocation = databaseLocation
        self.readOnly = readonly
        if databaseName.contains("/")  &&
            databaseName.suffix(9) != "SQLite.db" {
            self.readOnly = true
            self.path = databaseName
            self.ncDB = true
        } else {
            do {
                self.path = try UtilsFile.getFilePath(
                    databaseLocation: databaseLocation,
                    fileName: databaseName)
            } catch UtilsFileError.getFilePathFailed {
                throw DatabaseError.filePath(
                    message: "Could not generate the file path")
            }
        }
        print("database path \(self.path)")
    }

    // MARK: - isOpen

    func isDBOpen () -> Bool {
        return isOpen
    }

    // MARK: - isNCDB

    func isNCDB () -> Bool {
        return ncDB
    }

    // MARK: - getUrl

    func getUrl () -> String {
        return "file://\(path)"
    }

    // MARK: - Open

    // swiftlint:disable cyclomatic_complexity
    // swiftlint:disable function_body_length
    func open () throws {
        var password: String = ""
        // encryption/decryption paths removed

        do {
            mDb = try UtilsSQLCipher
                .openOrCreateDatabase(filename: path,
                                      password: password,
                                      readonly: self.readOnly)
            isOpen = true
            // PRAGMA foreign_keys = ON;
            try UtilsSQLCipher
                .setForeignKeyConstraintsEnabled(mDB: self,
                                                 toggle: true)
            if !ncDB && !self.readOnly {
                let curVersion: Int = try UtilsSQLCipher.getVersion(mDB: self)

                if dbVersion > curVersion && vUpgDict.count > 0 {
                    // backup the database
                    _ = try UtilsFile.copyFile(fileName: dbName,
                                               toFileName: "backup-\(dbName)",
                                               databaseLocation: databaseLocation)

                    _ = try uUpg
                        .onUpgrade(mDB: self, upgDict: vUpgDict,
                                   currentVersion: curVersion,
                                   targetVersion: dbVersion,
                                   databaseLocation: databaseLocation)

                    try UtilsSQLCipher
                        .deleteBackupDB(databaseLocation: databaseLocation,
                                        databaseName: dbName)
                }
            }
        } catch UtilsSQLCipherError.openOrCreateDatabase(let message) {
            var msg: String = "Failed in "
            msg.append("openOrCreateDatabase \(message)")
            throw DatabaseError.open(message: msg )
        } catch UtilsSQLCipherError
                    .setForeignKeyConstraintsEnabled(let message) {
            try close()
            var msg: String = "Failed in "
            msg.append("setForeignKeyConstraintsEnabled \(message)")
            throw DatabaseError.open(message: msg)
        } catch UtilsSQLCipherError.setVersion(let message) {
            try close()
            let msg: String = "Failed in setVersion \(message)"
            throw DatabaseError.open(message: msg)
        } catch UtilsSQLCipherError.getVersion(let message) {
            try close()
            let msg: String = "Failed in getVersion \(message)"
            throw DatabaseError.open(message: msg)
        } catch UtilsSQLCipherError.deleteBackupDB(let message) {
            try close()
            let msg: String = "Failed in deleteBackupDB \(message)"
            throw DatabaseError.open(message: msg)
        } catch UtilsUpgradeError.onUpgradeFailed(let message) {
            // restore the database
            do {
                try UtilsSQLCipher
                    .restoreDB(databaseLocation: databaseLocation,
                               databaseName: dbName)
                let msg: String = "Failed OnUpgrade \(message)"
                try close()
                throw DatabaseError.open(message: msg)

            } catch UtilsSQLCipherError.restoreDB(let message) {
                let msg: String = "Failed in restoreDB \(message)"
                try close()
                throw DatabaseError.open(message: msg)
            }
        }
        return
    }
    // swiftlint:enable function_body_length
    // swiftlint:enable cyclomatic_complexity

    // MARK: - Close

    func close () throws {
        if isOpen {
            // close the database
            do {
                try UtilsSQLCipher.closeDB(mDB: self)
                isOpen = false
            } catch UtilsSQLCipherError.closeDB(let message) {
                throw DatabaseError.close(
                    message: "Failed in close : \(message)" )
            }
        }
        return
    }

    // MARK: - IsAvailTrans

    func isAvailTrans() throws -> Bool {
        if isOpen {
            return isAvailableTransaction
        } else {
            let msg: String = "Failed in isAvailTrans database not opened"
            throw DatabaseError.isAvailTrans(message: msg)
        }
    }

    // MARK: - SetIsTransActive

    func setIsTransActive(newValue: Bool ) {
        isAvailableTransaction = newValue
    }

    // MARK: - BeginTransaction

    func beginTransaction() throws -> Int {
        if isOpen {
            do {
                try UtilsSQLCipher.beginTransaction(mDB: self)
                setIsTransActive(newValue: true)
                return 0
            } catch UtilsSQLCipherError.beginTransaction(let message) {
                let msg: String = "Failed in beginTransaction \(message)"
                throw DatabaseError.beginTransaction(message: msg)
            }
        } else {
            let msg: String = "Failed in beginTransaction database not opened"
            throw DatabaseError.beginTransaction(message: msg)
        }
    }

    // MARK: - CommitTransaction

    func commitTransaction() throws -> Int {
        if isOpen {
            do {
                try UtilsSQLCipher.commitTransaction(mDB: self)
                setIsTransActive(newValue: false)
                return 0
            } catch UtilsSQLCipherError.commitTransaction(let message) {
                let msg: String = "Failed in commitTransaction \(message)"
                throw DatabaseError.commitTransaction(message: msg)
            }
        } else {
            let msg: String = "Failed in commitTransaction database not opened"
            throw DatabaseError.commitTransaction(message: msg)
        }
    }

    // MARK: - RollbackTransaction

    func rollbackTransaction() throws -> Int {
        if isOpen {
            do {
                try UtilsSQLCipher.rollbackTransaction(mDB: self)
                setIsTransActive(newValue: false)
                return 0
            } catch UtilsSQLCipherError.rollbackTransaction(let message) {
                let msg: String = "Failed in rollbackTransaction \(message)"
                throw DatabaseError.rollbackTransaction(message: msg)
            }
        } else {
            let msg: String = "Failed in rollbackTransaction database not opened"
            throw DatabaseError.rollbackTransaction(message: msg)
        }
    }

    // MARK: - GetVersion

    func getVersion () throws -> Int {
        if isOpen {
            do {
                let curVersion: Int = try UtilsSQLCipher
                    .getVersion(mDB: self)
                return curVersion
            } catch UtilsSQLCipherError.getVersion(let message) {
                let msg: String = "Failed in getVersion \(message)"
                throw DatabaseError.getVersion(message: msg)
            }
        } else {
            let msg: String = "Failed in getVersion database not opened"
            throw DatabaseError.getVersion(message: msg)
        }
    }

    // MARK: - ExecuteSQL

    func executeSQL(sql: String, transaction: Bool = true) throws -> Int {
        var msg: String = "Failed in executeSQL : "
        var changes: Int = -1
        let initChanges = UtilsSQLCipher.dbChanges(mDB: mDb)

        // Start a transaction
        if transaction {
            do {
                try UtilsSQLCipher.beginTransaction(mDB: self)
            } catch UtilsSQLCipherError.beginTransaction(let message) {
                msg.append(" \(message)")
                throw DatabaseError.executeSQL(message: msg)
            }
        }
        // Execute the query
        do {
            try UtilsSQLCipher.execute(mDB: self, sql: sql)
            changes = UtilsSQLCipher.dbChanges(mDB: mDb) - initChanges

        } catch UtilsSQLCipherError.execute(let message) {
            if transaction {
                do {
                    try UtilsSQLCipher
                        .rollbackTransaction(mDB: self)
                } catch UtilsSQLCipherError
                            .rollbackTransaction(let message) {
                    msg.append(" rollback: \(message)")
                }
            }
            msg.append(" \(message)")
            throw DatabaseError.executeSQL(message: msg)
        }
        if changes != -1 && transaction {
            // commit the transaction
            do {
                try UtilsSQLCipher.commitTransaction(mDB: self)
            } catch UtilsSQLCipherError.commitTransaction(let msg) {
                throw DatabaseError.executeSQL(
                    message: "Failed in executeSQL : \(msg)" )
            }
        } else {
            if transaction {
                do {
                    try UtilsSQLCipher
                        .rollbackTransaction(mDB: self)
                } catch UtilsSQLCipherError
                            .rollbackTransaction(let message) {
                    msg.append(" rollback: \(message)")
                }
            }
        }
        return changes
    }

    // MARK: - ExecSet

    // swiftlint:disable function_body_length
    func execSet(set: [[String: Any]], transaction: Bool = true,
                 returnMode: String = "no") throws -> [String: Any] {
        var msg: String = "Failed in execSet : "
        let initChanges = UtilsSQLCipher.dbChanges(mDB: mDb)
        var changes: Int = -1
        var lastId: Int64 = -1
        var response: [[String: Any]] = []
        var changesDict: [String: Any] = ["lastId": lastId,
                                          "changes": changes,
                                          "values": [[:]]]

        // Start a transaction
        if transaction {
            do {
                try UtilsSQLCipher.beginTransaction(mDB: self)
            } catch UtilsSQLCipherError.beginTransaction(let message) {
                msg.append(" \(message)")
                throw DatabaseError.execSet(message: msg)
            }
        }
        // Execute the query
        do {
            let resp = try UtilsSQLCipher
                .executeSet(mDB: self, set: set, returnMode: returnMode)
            lastId = resp.0
            response = resp.1
            changes = UtilsSQLCipher
                .dbChanges(mDB: mDb) - initChanges
            changesDict["changes"] = changes
            changesDict["lastId"] = lastId
            changesDict["values"] = response

        } catch UtilsSQLCipherError
                    .executeSet(let message) {
            if transaction {
                do {
                    try UtilsSQLCipher
                        .rollbackTransaction(mDB: self)
                } catch UtilsSQLCipherError
                            .rollbackTransaction(let message) {
                    msg.append(" rollback: \(message)")
                }
            }
            msg.append(" \(message)")
            throw DatabaseError.execSet(message: msg )
        }
        if changes >= 0 && transaction {
            // commit the transaction
            do {
                try UtilsSQLCipher.commitTransaction(mDB: self)
            } catch UtilsSQLCipherError.commitTransaction(let msg) {
                throw DatabaseError.execSet(
                    message: msg )
            }
        }
        return changesDict
    }
    // swiftlint:enable function_body_length

    // MARK: - RunSQL

    func runSQL(sql: String, values: [Any], transaction: Bool = true,
                returnMode: String = "no") throws -> [String: Any] {
        var msg: String = "Failed in runSQL : "
        var changes: Int = -1
        var lastId: Int64 = -1
        var response: [[String: Any]] = []
        let initChanges = UtilsSQLCipher.dbChanges(mDB: mDb)
        // Start a transaction
        if transaction {
            do {
                try UtilsSQLCipher.beginTransaction(mDB: self)
            } catch UtilsSQLCipherError.beginTransaction(let message) {

                msg.append(" \(message)")
                throw DatabaseError.runSQL(message: msg)
            }
        }
        // Execute the query
        do {
            let resp = try UtilsSQLCipher
                .prepareSQL(mDB: self, sql: sql, values: values,
                            fromJson: false, returnMode: returnMode)
            lastId = resp.0
            response = resp.1
        } catch UtilsSQLCipherError.prepareSQL(let message) {
            if transaction {
                do {
                    try UtilsSQLCipher
                        .rollbackTransaction(mDB: self)
                } catch UtilsSQLCipherError
                            .rollbackTransaction(let message) {
                    msg.append(" rollback: \(message)")
                }
            }
            msg.append(" \(message)")
            lastId = -1
            throw DatabaseError.runSQL(message: msg )
        }

        if lastId != -1 {
            if transaction {
                // commit the transaction
                do {
                    try UtilsSQLCipher.commitTransaction(mDB: self)
                } catch UtilsSQLCipherError.commitTransaction(let message) {
                    msg.append(" \(message)")
                    throw DatabaseError.runSQL(message: msg )
                }
            }
        }
        changes = UtilsSQLCipher.dbChanges(mDB: mDb) - initChanges
        let result: [String: Any] = ["changes": changes,
                                     "lastId": lastId,
                                     "values": response]
        return result
    }

    // MARK: - SelectSQL

    func selectSQL(sql: String, values: [Any])
    throws -> [[String: Any]] {
        var result: [[String: Any]] = []
        do {
            result = try UtilsSQLCipher.querySQL(mDB: self, sql: sql,
                                                 values: values)
        } catch UtilsSQLCipherError.querySQL(let msg) {
            throw DatabaseError.selectSQL(
                message: "Failed in selectSQL : \(msg)" )
        }
        return result
    }

    // MARK: - GetTableNames

    func getTableNames() throws -> [String] {
        var result: [String] = []
        do {
            result = try UtilsDrop.getTablesNames(mDB: self)
        } catch UtilsDropError.getTablesNamesFailed(let msg) {
            throw DatabaseError.getTableNames(
                message: "Failed in getTableNames : \(msg)" )
        }
        return result
    }

    // MARK: - DeleteDB

    func deleteDB(databaseName: String) throws -> Bool {
        let isFileExists: Bool = UtilsFile
            .isFileExist(databaseLocation: databaseLocation,
                         fileName: databaseName)
        if isFileExists && !isOpen {
            // open the database
            do {
                try self.open()
            } catch DatabaseError.open( let message ) {
                throw DatabaseError.deleteDB(message: message)
            }
        }
        // close the database
        do {
            try self.close()
        } catch DatabaseError.close( let message ) {
            throw DatabaseError.deleteDB(message: message)
        }
        // delete the database
        if isFileExists {
            do {
                try UtilsSQLCipher.deleteDB(databaseLocation: databaseLocation,
                                            databaseName: databaseName)
            } catch UtilsSQLCipherError.deleteDB(let message ) {
                throw DatabaseError.deleteDB(message: message)
            }
        }
        return true
    }

    // MARK: - createSyncTable

    func createSyncTable() throws -> Int {
        var retObj: Int = -1
        // Open the database for writing
        // check if the table has already been created
        do {
            let isExists: Bool = try UtilsJson.isTableExists(
                mDB: self, tableName: "sync_table")
            if !isExists {
                // check if there are tables with last_modified column
                let isLastModified: Bool = try UtilsJson.isLastModified(mDB: self)
                let isSqlDeleted: Bool = try UtilsJson.isSqlDeleted(mDB: self)
                if isLastModified && isSqlDeleted {
                    let date = Date()
                    let syncTime: Int = Int(date.timeIntervalSince1970)
                    var stmt: String = "CREATE TABLE IF NOT EXISTS "
                    stmt.append("sync_table (")
                    stmt.append("id INTEGER PRIMARY KEY NOT NULL,")
                    stmt.append("sync_date INTEGER);")
                    stmt.append("INSERT INTO sync_table (sync_date) ")
                    stmt.append("VALUES ('\(syncTime)');")
                    retObj = try executeSQL(sql: stmt)
                } else {
                    let msg = "No last_modified column in tables"
                    throw DatabaseError.createSyncTable(message: msg)
                }
            } else {
                retObj = 0
            }
        } catch UtilsJsonError.isLastModified(let message) {
            throw DatabaseError.createSyncTable(message: message)
        } catch UtilsJsonError.isSqlDeleted(let message) {
            throw DatabaseError.createSyncTable(message: message)
        } catch UtilsJsonError.tableNotExists(let message) {
            throw DatabaseError.createSyncTable(message: message)
        } catch DatabaseError.executeSQL(let message) {
            throw DatabaseError.createSyncTable(message: message)
        }
        return retObj
    }

    // MARK: - SetSyncDate

    func setSyncDate(syncDate: String ) throws -> Bool {
        var retBool: Bool = false
        var lastId: Int64 = -1
        var resp: [String: Any] = [:]
        do {
            let isExists: Bool = try UtilsJson.isTableExists(
                mDB: self, tableName: "sync_table")
            if !isExists {
                throw DatabaseError.createSyncDate(message: "No sync_table available")
            }
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            if let date = dateFormatter.date(from: syncDate) {
                let syncTime: Int = Int(date.timeIntervalSince1970)
                var stmt: String = "UPDATE sync_table SET sync_date = "
                stmt.append("\(syncTime) WHERE id = 1;")
                resp = try runSQL(sql: stmt, values: [])
                if let mLastId: Int64 = resp["lastId"] as? Int64 {
                    lastId = mLastId
                    if lastId != -1 {
                        retBool = true
                    }
                }
            } else {
                throw DatabaseError.createSyncDate(message: "wrong syncDate")
            }
        } catch UtilsJsonError.tableNotExists(let message) {
            throw DatabaseError.createSyncDate(message: message)
        } catch DatabaseError.runSQL(let message) {
            throw DatabaseError.createSyncDate(message: message)
        }
        return retBool
    }

    // MARK: - GetSyncDate

    func getSyncDate( ) throws -> Int64 {
        var syncDate: Int64 = 0
        do {
            let isExists: Bool = try UtilsJson.isTableExists(
                mDB: self, tableName: "sync_table")
            if !isExists {
                throw DatabaseError.getSyncDate(message: "No sync_table available")
            }
            syncDate = try ExportToJson.getSyncDate(mDB: self)
        } catch UtilsJsonError.tableNotExists(let message) {
            throw DatabaseError.getSyncDate(message: message)
        } catch ExportToJsonError.getSyncDate(let message) {
            throw DatabaseError.getSyncDate(message: message)
        }
        return syncDate
    }

    // MARK: - ExportToJson

    func exportToJson(expMode: String, isEncrypted: Bool)
    throws -> [String: Any] {
        var retObj: [String: Any] = [:]

        do {
            let date = Date()
            let syncTime: Int = Int(date.timeIntervalSince1970)
            let isExists: Bool = try UtilsJson.isTableExists(
                mDB: self, tableName: "sync_table")
            if isExists {
                // Set the last exported date
                try ExportToJson.setLastExportDate(mDB: self, sTime: syncTime)
            } else {
                if expMode == "partial" {
                    throw DatabaseError.exportToJson(message: "No sync_table available")
                }
            }
            // Launch the export process
            let data: [String: Any] = [
                "dbName": dbName, "encrypted": self.encrypted,
                "expMode": expMode, "version": dbVersion]
            retObj = try ExportToJson
                .createExportObject(mDB: self, data: data)
            if isEncryption && encrypted && isEncrypted {
                retObj["overwrite"] = true
                let base64Str = try UtilsJson.encryptDictionaryToBase64(
                    retObj,
                    forAccount: account)
                retObj = [:]
                retObj["expData"] = base64Str
            }

        } catch UtilsJsonError.tableNotExists(let message) {
            throw DatabaseError.exportToJson(message: message)
        } catch ExportToJsonError.setLastExportDate(let message) {
            throw DatabaseError.exportToJson(message: message)
        } catch ExportToJsonError.createExportObject(let message) {
            throw DatabaseError.exportToJson(message: message)
        }
        return retObj
    }

    // MARK: - DeleteExportedRows()

    func deleteExportedRows() throws {

        do {
            try ExportToJson.delExportedRows(mDB: self)
        } catch ExportToJsonError.delExportedRows(let message) {
            throw DatabaseError.exportToJson(message: message)
        }
    }

    // MARK: - ImportFromJson

    func importFromJson(importData: ImportData)
    throws -> [String: Int] {
        var changes: Int = 0

        // Create the Database Schema
        do {
            // PRAGMA foreign_keys = OFF;
            try UtilsSQLCipher
                .setForeignKeyConstraintsEnabled(mDB: self,
                                                 toggle: false)
            if importData.tables.count > 0 {
                changes = try ImportFromJson
                    .createDatabaseSchema(mDB: self,
                                          tables: importData.tables,
                                          mode: importData.mode,
                                          version: importData.version)
                if changes != -1 {
                    // Create the Database Data
                    changes += try ImportFromJson
                        .createDatabaseData(mDB: self,
                                            tables: importData.tables,
                                            mode: importData.mode)
                }
            }
            if let mViews = importData.views {
                if mViews.count > 0 {
                    changes += try ImportFromJson
                        .createViews(mDB: self, views: mViews)
                }
            }
            // PRAGMA foreign_keys = ON;
            try UtilsSQLCipher
                .setForeignKeyConstraintsEnabled(mDB: self,
                                                 toggle: true)

            return ["changes": changes]
        } catch ImportFromJsonError.createDatabaseSchema(let message) {
            throw DatabaseError.importFromJson(message: message)
        } catch ImportFromJsonError.createDatabaseData(let message) {
            throw DatabaseError.importFromJson(message: message)
        } catch ImportFromJsonError.createViews(let message) {
            throw DatabaseError.importFromJson(message: message)
        }
    }
}
// swiftlint:enable type_body_length
// swiftlint:enable file_length

// Minimal non-encrypted shim to satisfy calls formerly in UtilsSQLCipher.swift
import SQLite3

enum UtilsSQLCipherError: Error {
    case openOrCreateDatabase(message: String)
    case close(message: String)
    case closeDB(message: String)
    case beginTransaction(message: String)
    case commitTransaction(message: String)
    case rollbackTransaction(message: String)
    case querySQL(message: String)
    case prepareSQL(message: String)
    case execute(message: String)
    case setForeignKeyConstraintsEnabled(message: String)
    case setVersion(message: String)
    case getVersion(message: String)
    case restoreDB(message: String)
    case deleteBackupDB(message: String)
    case deleteDB(message: String)
    case executeSet(message: String)
    case bindFailed
}

class UtilsSQLCipher {
    class func openOrCreateDatabase(filename: String, password: String = "", readonly: Bool = false) throws -> OpaquePointer? {
        let flags = readonly ? SQLITE_OPEN_READONLY : (SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE)
        var mDB: OpaquePointer?
        if sqlite3_open_v2(filename, &mDB, flags | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK {
            // simple sanity check
            var ok = false
            let stmt = "SELECT count(*) FROM sqlite_master;"
            if sqlite3_exec(mDB, stmt, nil, nil, nil) == SQLITE_OK { ok = true }
            if ok { return mDB }
            throw UtilsSQLCipherError.openOrCreateDatabase(message: "Cannot open the DB")
        } else {
            throw UtilsSQLCipherError.openOrCreateDatabase(message: "open_v2 failed")
        }
    }

    class func close(oDB: OpaquePointer?) throws {
        let rc = sqlite3_close_v2(oDB)
        if rc != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(oDB))
            throw UtilsSQLCipherError.close(message: "rc: \(rc) message: \(errmsg)")
        }
    }

    class func closeDB(mDB: Database) throws {
        if !mDB.isDBOpen() { throw UtilsSQLCipherError.closeDB(message: "Database not opened") }
        try UtilsSQLCipher.close(oDB: mDB.mDb)
    }

    class func setForeignKeyConstraintsEnabled(mDB: Database, toggle: Bool) throws {
        if !mDB.isDBOpen() { throw UtilsSQLCipherError.execute(message: "Database not opened") }
        let key = toggle ? "ON" : "OFF"
        let sql = "PRAGMA foreign_keys = \(key);"
        if sqlite3_exec(mDB.mDb, sql, nil, nil, nil) != SQLITE_OK {
            throw UtilsSQLCipherError.setForeignKeyConstraintsEnabled(message: "set foreign_keys failed")
        }
    }

    class func getForeignKeysState(mDB: Database) throws -> Int {
        let sql = "PRAGMA foreign_keys;"
        let res = try querySQL(mDB: mDB, sql: sql, values: [])
        if res.count > 1, let val = res[1]["foreign_keys"] as? Int64 { return Int(val) }
        return 0
    }

    class func getVersion(mDB: Database) throws -> Int {
        let sql = "PRAGMA user_version;"
        let res = try querySQL(mDB: mDB, sql: sql, values: [])
        if res.count > 1, let val = res[1]["user_version"] as? Int64 { return Int(val) }
        return 0
    }

    class func setVersion(mDB: Database, version: Int) throws {
        let sql = "PRAGMA user_version = \(version);"
        if sqlite3_exec(mDB.mDb, sql, nil, nil, nil) != SQLITE_OK {
            throw UtilsSQLCipherError.setVersion(message: "set user_version failed")
        }
    }

    class func beginTransaction(mDB: Database) throws {
        if sqlite3_exec(mDB.mDb, "BEGIN TRANSACTION;", nil, nil, nil) != SQLITE_OK {
            throw UtilsSQLCipherError.beginTransaction(message: "begin failed")
        }
    }

    class func commitTransaction(mDB: Database) throws {
        if sqlite3_exec(mDB.mDb, "COMMIT TRANSACTION;", nil, nil, nil) != SQLITE_OK {
            throw UtilsSQLCipherError.commitTransaction(message: "commit failed")
        }
    }

    class func rollbackTransaction(mDB: Database) throws {
        if sqlite3_exec(mDB.mDb, "ROLLBACK TRANSACTION;", nil, nil, nil) != SQLITE_OK {
            throw UtilsSQLCipherError.rollbackTransaction(message: "rollback failed")
        }
    }

    class func dbChanges(mDB: OpaquePointer?) -> Int { return Int(sqlite3_total_changes(mDB)) }
    class func dbLastId(mDB: OpaquePointer?) -> Int64 { return sqlite3_last_insert_rowid(mDB) }

    class func execute(mDB: Database, sql: String) throws {
        if sqlite3_exec(mDB.mDb, sql, nil, nil, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(mDB.mDb))
            throw UtilsSQLCipherError.execute(message: errmsg)
        }
    }

    class func prepareSQL(mDB: Database, sql: String, values: [Any], fromJson: Bool, returnMode: String) throws -> (Int64, [[String: Any]]) {
        var stmt: OpaquePointer?
        var results: [[String: Any]] = []
        var lastId: Int64 = -1
        var rc = sqlite3_prepare_v2(mDB.mDb, sql, -1, &stmt, nil)
        if rc != SQLITE_OK { let errmsg = String(cString: sqlite3_errmsg(mDB.mDb)); throw UtilsSQLCipherError.prepareSQL(message: errmsg) }
        if !values.isEmpty {
            _ = UtilsBinding.bindValues(handle: stmt, values: values)
        }
        rc = sqlite3_step(stmt)
        if rc != SQLITE_DONE && rc != SQLITE_ROW {
            let errmsg = String(cString: sqlite3_errmsg(mDB.mDb))
            sqlite3_finalize(stmt)
            throw UtilsSQLCipherError.prepareSQL(message: errmsg)
        }
        if rc == SQLITE_ROW {
            // collect single row
            let colCount = sqlite3_column_count(stmt)
            var header: [String: Any] = [:]
            var names: [String] = []
            for i in 0..<colCount { if let n = sqlite3_column_name(stmt, i) { names.append(String(cString: n)) } }
            header["ios_columns"] = names
            results.append(header)
            repeat {
                var row: [String: Any] = [:]
                for i in 0..<colCount {
                    let type = sqlite3_column_type(stmt, i)
                    if let name = sqlite3_column_name(stmt, i) {
                        let key = String(cString: name)
                        switch type {
                        case SQLITE_INTEGER: row[key] = Int64(sqlite3_column_int64(stmt, i))
                        case SQLITE_FLOAT: row[key] = sqlite3_column_double(stmt, i)
                        case SQLITE_TEXT: row[key] = String(cString: sqlite3_column_text(stmt, i))
                        case SQLITE_BLOB:
                            if let blob = sqlite3_column_blob(stmt, i) {
                                let len = Int(sqlite3_column_bytes(stmt, i))
                                let data = Data(bytes: blob, count: len)
                                row[key] = [UInt8](data)
                            } else { row[key] = NSNull() }
                        default: row[key] = NSNull()
                        }
                    }
                }
                results.append(row)
            } while sqlite3_step(stmt) == SQLITE_ROW
        } else {
            lastId = dbLastId(mDB: mDB.mDb)
        }
        sqlite3_finalize(stmt)
        return (lastId, results)
    }

    class func querySQL(mDB: Database, sql: String, values: [Any]) throws -> [[String: Any]] {
        var stmt: OpaquePointer?
        var rc = sqlite3_prepare_v2(mDB.mDb, sql, -1, &stmt, nil)
        if rc != SQLITE_OK { let errmsg = String(cString: sqlite3_errmsg(mDB.mDb)); throw UtilsSQLCipherError.querySQL(message: errmsg) }
        if !values.isEmpty { _ = UtilsBinding.bindValues(handle: stmt, values: values) }
        var result: [[String: Any]] = []
        let colCount = sqlite3_column_count(stmt)
        var header: [String: Any] = [:]
        var names: [String] = []
        for i in 0..<colCount { if let n = sqlite3_column_name(stmt, i) { names.append(String(cString: n)) } }
        header["ios_columns"] = names
        result.append(header)
        while sqlite3_step(stmt) == SQLITE_ROW {
            var row: [String: Any] = [:]
            for i in 0..<colCount {
                if let name = sqlite3_column_name(stmt, i) {
                    let key = String(cString: name)
                    let type = sqlite3_column_type(stmt, i)
                    switch type {
                    case SQLITE_INTEGER: row[key] = Int64(sqlite3_column_int64(stmt, i))
                    case SQLITE_FLOAT: row[key] = sqlite3_column_double(stmt, i)
                    case SQLITE_TEXT: row[key] = String(cString: sqlite3_column_text(stmt, i))
                    case SQLITE_BLOB:
                        if let blob = sqlite3_column_blob(stmt, i) {
                            let len = Int(sqlite3_column_bytes(stmt, i))
                            let data = Data(bytes: blob, count: len)
                            row[key] = [UInt8](data)
                        } else { row[key] = NSNull() }
                    default: row[key] = NSNull()
                    }
                }
            }
            result.append(row)
        }
        sqlite3_finalize(stmt)
        return result
    }

    class func executeSet(mDB: Database, set: [[String: Any]], returnMode: String) throws -> (Int64, [[String: Any]]) {
        var lastId: Int64 = -1
        var response: [[String: Any]] = []
        for dict in set {
            guard let sql = dict["statement"] as? String, let values = dict["values"] as? [Any] else {
                throw UtilsSQLCipherError.prepareSQL(message: "No statement/values")
            }
            let resp = try prepareSQL(mDB: mDB, sql: sql, values: values, fromJson: false, returnMode: returnMode)
            lastId = resp.0
            response = addToResponse(response: response, respSet: resp.1)
        }
        return (lastId, response)
    }

    class func addToResponse(response: [[String: Any]], respSet: [[String: Any]]) -> [[String: Any]] {
        var ret = response
        var m = respSet
        if !ret.isEmpty {
            m = m.filter { dict in !(dict.keys.first == "ios_columns") }
        }
        ret.append(contentsOf: m)
        return ret
    }

    class func restoreDB(databaseLocation: String, databaseName: String) throws {
        // no-op shim
    }
    class func deleteBackupDB(databaseLocation: String, databaseName: String) throws { /* no-op */ }
    class func parse(mVar: Any) -> Bool { return mVar is NSArray }

    // Minimal state to satisfy callers expecting encryption state
}

// Provide a minimal State enum for getDatabaseState compatibility
enum State: String {
    case ENCRYPTEDGLOBALSECRET
    case ENCRYPTEDSECRET
    case UNENCRYPTED
}

extension UtilsSQLCipher {
    class func deleteDB(databaseLocation: String, databaseName: String) throws {
        do {
            let dbPath = try UtilsFile.getFilePath(databaseLocation: databaseLocation, fileName: databaseName)
            if UtilsFile.isFileExist(filePath: dbPath) {
                _ = try UtilsFile.deleteFile(filePath: dbPath)
            }
        } catch UtilsFileError.getFilePathFailed {
            throw UtilsSQLCipherError.deleteDB(message: "getFilePath failed")
        } catch UtilsFileError.deleteFileFailed {
            throw UtilsSQLCipherError.deleteDB(message: "deleteFile failed")
        }
    }

    // Always report unencrypted in the non-encrypted shim
    class func getDatabaseState(databaseLocation: String, databaseName: String, account: String) -> State {
        return .UNENCRYPTED
    }
}
