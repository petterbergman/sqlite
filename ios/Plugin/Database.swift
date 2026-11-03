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
    case execSet(message: String)
    case exportToJson(message: String)
    case importFromJson(message: String)
    case getTableNames(message: String)
}
// swiftlint:disable file_length
// swiftlint:disable type_body_length
class Database {
    var isOpen: Bool = false
    var dbName: String
    var dbVersion: Int
    var path: String = ""
    var mDb: OpaquePointer?

    // MARK: - Init
    init(databaseLocation: String, databaseName: String, version: Int) throws {
        self.dbVersion = version
        self.dbName = databaseName
        do {
            self.path = try UtilsFile.getFilePath(
                databaseLocation: databaseLocation,
                fileName: databaseName)
        } catch UtilsFileError.getFilePathFailed {
            throw DatabaseError.filePath(
                message: "Could not generate the file path")
        }
        print("database path \(self.path)")
    }

    // MARK: - isOpen

    func isDBOpen() -> Bool {
        return isOpen
    }

    // MARK: - Open

    func open() throws {
        do {
            mDb = try UtilsSQLCipher.openOrCreateDatabase(filename: path)
            isOpen = true
            // PRAGMA foreign_keys = ON;
            try UtilsSQLCipher
                .setForeignKeyConstraintsEnabled(mDB: self,
                                                 toggle: true)
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
        }
    }

    // MARK: - Close

    func close() throws {
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

    // MARK: - GetVersion

    func getVersion() throws -> Int {
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

    func execSet(set: [[String: Any]], transaction: Bool = true) throws -> [String: Any] {
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
                .executeSet(mDB: self, set: set)
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

    // MARK: - RunSQL

    func runSQL(sql: String, values: [Any], transaction: Bool = true) throws -> [String: Any] {
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
                .prepareSQL(mDB: self, sql: sql, values: values)
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

    // MARK: - ExportToJson

    func exportToJson() throws -> [String: Any] {
        do {
            return try ExportToJson.createExportObject(mDB: self, dbName: dbName,
                                                       version: dbVersion)
        } catch ExportToJsonError.createExportObject(let message) {
            throw DatabaseError.exportToJson(message: message)
        }
    }

    // MARK: - ImportFromJson

    func importFromJson(jsonSQLite: JsonSQLite)
    throws -> [String: Int] {
        var changes: Int = 0

        // Create the Database Schema
        do {
            // PRAGMA foreign_keys = OFF;
            try UtilsSQLCipher
                .setForeignKeyConstraintsEnabled(mDB: self,
                                                 toggle: false)
            if jsonSQLite.tables.count > 0 {
                changes = try ImportFromJson
                    .createDatabaseSchema(mDB: self,
                                          tables: jsonSQLite.tables,
                                          version: jsonSQLite.version)
                if changes != -1 {
                    // Create the Database Data
                    changes += try ImportFromJson
                        .createDatabaseData(mDB: self,
                                            tables: jsonSQLite.tables)
                }
            }
            if let mViews = jsonSQLite.views, mViews.count > 0 {
                changes += try ImportFromJson
                    .createViews(mDB: self, views: mViews)
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
// Keep file_length disabled for this compatibility shim extension block.

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
    case executeSet(message: String)
    case bindFailed
}

class UtilsSQLCipher {
    class func openOrCreateDatabase(filename: String) throws -> OpaquePointer? {
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE
        var mDB: OpaquePointer?
        if sqlite3_open_v2(filename, &mDB, flags | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK {
            // simple sanity check
            var isValid = false
            let stmt = "SELECT count(*) FROM sqlite_master;"
            if sqlite3_exec(mDB, stmt, nil, nil, nil) == SQLITE_OK { isValid = true }
            if isValid { return mDB }
            throw UtilsSQLCipherError.openOrCreateDatabase(message: "Cannot open the DB")
        } else {
            throw UtilsSQLCipherError.openOrCreateDatabase(message: "open_v2 failed")
        }
    }

    class func close(oDB: OpaquePointer?) throws {
        let resCode = sqlite3_close_v2(oDB)
        if resCode != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(oDB))
            throw UtilsSQLCipherError.close(message: "rc: \(resCode) message: \(errmsg)")
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

    class func prepareSQL(mDB: Database, sql: String, values: [Any]) throws -> (Int64, [[String: Any]]) {
        var stmt: OpaquePointer?
        var results: [[String: Any]] = []
        var lastId: Int64 = -1
        var resCode = sqlite3_prepare_v2(mDB.mDb, sql, -1, &stmt, nil)
        if resCode != SQLITE_OK { let errmsg = String(cString: sqlite3_errmsg(mDB.mDb)); throw UtilsSQLCipherError.prepareSQL(message: errmsg) }
        if !values.isEmpty {
            _ = UtilsBinding.bindValues(handle: stmt, values: values)
        }
        resCode = sqlite3_step(stmt)
        if resCode != SQLITE_DONE && resCode != SQLITE_ROW {
            let errmsg = String(cString: sqlite3_errmsg(mDB.mDb))
            sqlite3_finalize(stmt)
            throw UtilsSQLCipherError.prepareSQL(message: errmsg)
        }
        if resCode == SQLITE_ROW {
            // collect single row
            let colCount = sqlite3_column_count(stmt)
            var header: [String: Any] = [:]
            var names: [String] = []
            for columnIndex in 0..<colCount {
                if let columnName = sqlite3_column_name(stmt, columnIndex) {
                    names.append(String(cString: columnName))
                }
            }
            header["ios_columns"] = names
            results.append(header)
            repeat {
                var row: [String: Any] = [:]
                for columnIndex in 0..<colCount {
                    let type = sqlite3_column_type(stmt, columnIndex)
                    if let name = sqlite3_column_name(stmt, columnIndex) {
                        let key = String(cString: name)
                        switch type {
                        case SQLITE_INTEGER: row[key] = Int64(sqlite3_column_int64(stmt, columnIndex))
                        case SQLITE_FLOAT: row[key] = sqlite3_column_double(stmt, columnIndex)
                        case SQLITE_TEXT: row[key] = String(cString: sqlite3_column_text(stmt, columnIndex))
                        case SQLITE_BLOB:
                            if let blob = sqlite3_column_blob(stmt, columnIndex) {
                                let len = Int(sqlite3_column_bytes(stmt, columnIndex))
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
        var resCode = sqlite3_prepare_v2(mDB.mDb, sql, -1, &stmt, nil)
        if resCode != SQLITE_OK { let errmsg = String(cString: sqlite3_errmsg(mDB.mDb)); throw UtilsSQLCipherError.querySQL(message: errmsg) }
        if !values.isEmpty { _ = UtilsBinding.bindValues(handle: stmt, values: values) }
        var result: [[String: Any]] = []
        let colCount = sqlite3_column_count(stmt)
        var header: [String: Any] = [:]
        var names: [String] = []
        for columnIndex in 0..<colCount {
            if let columnName = sqlite3_column_name(stmt, columnIndex) {
                names.append(String(cString: columnName))
            }
        }
        header["ios_columns"] = names
        result.append(header)
        while sqlite3_step(stmt) == SQLITE_ROW {
            var row: [String: Any] = [:]
            for columnIndex in 0..<colCount {
                if let name = sqlite3_column_name(stmt, columnIndex) {
                    let key = String(cString: name)
                    let type = sqlite3_column_type(stmt, columnIndex)
                    switch type {
                    case SQLITE_INTEGER: row[key] = Int64(sqlite3_column_int64(stmt, columnIndex))
                    case SQLITE_FLOAT: row[key] = sqlite3_column_double(stmt, columnIndex)
                    case SQLITE_TEXT: row[key] = String(cString: sqlite3_column_text(stmt, columnIndex))
                    case SQLITE_BLOB:
                        if let blob = sqlite3_column_blob(stmt, columnIndex) {
                            let len = Int(sqlite3_column_bytes(stmt, columnIndex))
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

    class func executeSet(mDB: Database, set: [[String: Any]]) throws -> (Int64, [[String: Any]]) {
        var lastId: Int64 = -1
        var response: [[String: Any]] = []
        for dict in set {
            guard let sql = dict["statement"] as? String, let values = dict["values"] as? [Any] else {
                throw UtilsSQLCipherError.prepareSQL(message: "No statement/values")
            }
            let resp = try prepareSQL(mDB: mDB, sql: sql, values: values)
            lastId = resp.0
            response = addToResponse(response: response, respSet: resp.1)
        }
        return (lastId, response)
    }

    class func addToResponse(response: [[String: Any]], respSet: [[String: Any]]) -> [[String: Any]] {
        var ret = response
        var mergedResponseSet = respSet
        if !ret.isEmpty {
            mergedResponseSet = mergedResponseSet.filter { dict in !(dict.keys.first == "ios_columns") }
        }
        ret.append(contentsOf: mergedResponseSet)
        return ret
    }

}
