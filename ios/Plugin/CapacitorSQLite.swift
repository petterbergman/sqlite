import Foundation
import Capacitor

enum CapacitorSQLiteError: Error {
    case failed(message: String)
}
// swiftlint:disable file_length
// swiftlint:disable type_body_length
@objc public class CapacitorSQLite: NSObject {
    private var dbDict: [String: Database] = [:]
    private var databaseLocation: String = "Documents"
    private var initMessage: String = ""
    private var isInit: Bool = false

    init(config: SqliteConfig) {
        super.init()

        if let dbLocation = config.iosDatabaseLocation {
            self.databaseLocation = dbLocation
            // create the databaseLocation directory
            do {
                try UtilsFile.createDatabaseLocation(location: dbLocation)
                isInit = true
            } catch UtilsFileError.createDatabaseLocationFailed(let message) {
                initMessage =  message
            } catch let error {
                initMessage = "Init Plugin failed :"
                initMessage.append(" \(error.localizedDescription)")
            }

        } else {
            self.databaseLocation = "Documents"
            isInit = true
        }
    }

    // MARK: - CreateConnection

    @objc public func createConnection(_ dbName: String, version: Int) throws {
        guard isInit else {
            throw CapacitorSQLiteError.failed(message: initMessage)
        }
        let mDbName = CapacitorSQLite.getDatabaseName(dbName: dbName)
        // check if the connection already exists
        if dbDict[mDbName] != nil {
            let msg = "Connection \(mDbName) already exists"
            throw CapacitorSQLiteError.failed(message: msg)
        }
        do {
            let mDb: Database = try Database(
                databaseLocation: databaseLocation,
                databaseName: "\(mDbName)SQLite.db",
                version: version)

            dbDict[mDbName] = mDb
            return
        } catch let error {
            throw CapacitorSQLiteError.failed(message: "\(error)")
        }
    }

    // MARK: - Open

    @objc public func open(_ dbName: String) throws {
        let mDb = try getConnection(dbName)
        do {
            try mDb.open()
            return
        } catch DatabaseError.open(let message) {
            throw CapacitorSQLiteError.failed(message: message)
        }
    }

    // MARK: - Close

    @objc public func close(_ dbName: String) throws {
        let mDb = try getConnection(dbName)
        do {
            try mDb.close()
            return
        } catch DatabaseError.close(let message) {
            throw CapacitorSQLiteError.failed(message: message)
        }
    }

    // MARK: - Close Connection

    @objc public func closeConnection(_ dbName: String) throws {
        guard isInit else {
            throw CapacitorSQLiteError.failed(message: initMessage)
        }
        let mDbName = CapacitorSQLite.getDatabaseName(dbName: dbName)
        guard let mDb: Database = dbDict[mDbName] else {
            return
        }
        if mDb.isDBOpen() {
            do {
                try mDb.close()
            } catch DatabaseError.close(let message) {
                throw CapacitorSQLiteError.failed(message: message)
            }
        }
        dbDict.removeValue(forKey: mDbName)
        return
    }

    // MARK: - CheckConnectionsConsistency

    @objc public func checkConnectionsConsistency(_ dbNames: [String]) throws -> NSNumber {
        guard isInit else {
            throw CapacitorSQLiteError.failed(message: initMessage)
        }
        let conns = Set(dbNames.map { CapacitorSQLite.getDatabaseName(dbName: $0) })
        do {
            if conns.isEmpty || dbDict.count < conns.count {
                // not solvable inconsistency
                try closeAllConnections()
                return 0
            }
            // drop native connections the JS side no longer knows about
            for key in dbDict.keys where !conns.contains(key) {
                dbDict.removeValue(forKey: key)
            }
            if Set(dbDict.keys) == conns {
                return 1
            }
            try closeAllConnections()
            return 0
        } catch let error {
            throw CapacitorSQLiteError.failed(message: "\(error)")
        }
    }

    // MARK: - IsDatabase

    @objc public func isDatabase(_ dbName: String) throws -> NSNumber {
        guard isInit else {
            throw CapacitorSQLiteError.failed(message: initMessage)
        }
        let mDbName = CapacitorSQLite.getDatabaseName(dbName: dbName)
        let isFileExists: Bool = UtilsFile
            .isFileExist(databaseLocation: databaseLocation,
                         fileName: mDbName + "SQLite.db")
        return isFileExists ? 1 : 0
    }

    // MARK: - Execute

    @objc public func execute(_ dbName: String, statements: String,
                              transaction: Bool)
    throws -> [String: Any] {
        let mDb = try getOpenConnection(dbName)
        do {
            var stmts = statements
            // remove carriage returns
            let isReturn = stmts.indicesOf(string: "\n")
            if isReturn.count != 0 {
                let cmds = stmts.split(separator: "\n")
                var strcmds: [String] = []
                for cmd in cmds {
                    strcmds.append(String(cmd
                                            .trimmingCharacters(in: .whitespacesAndNewlines)))
                }
                stmts = strcmds.joined(separator: "\n")
            }
            let res = try mDb.executeSQL(sql: stmts,
                                         transaction: transaction)
            return ["changes": res]
        } catch DatabaseError.executeSQL(let message) {
            throw CapacitorSQLiteError.failed(message: message)
        } catch let error {
            let msg: String = "\(error)"
            throw CapacitorSQLiteError.failed(message: msg)
        }
    }

    // MARK: - ExecuteSet

    @objc func executeSet(_ dbName: String, set: [[String: Any]],
                          transaction: Bool)
    throws -> [String: Any] {
        let mDb = try getOpenConnection(dbName)
        do {
            let res = try mDb.execSet(set: set, transaction: transaction)
            return res
        } catch DatabaseError.execSet(let message) {
            throw CapacitorSQLiteError.failed(message: message)
        } catch let error {
            let msg: String = "\(error)"
            throw CapacitorSQLiteError.failed(message: msg)
        }
    }

    // MARK: - Run

    // swiftlint:disable function_body_length
    // swiftlint:disable cyclomatic_complexity
    @objc func run(_ dbName: String, statement: String, values: [Any],
                   transaction: Bool)
    throws -> [String: Any] {
        let mDb = try getOpenConnection(dbName)
        do {
            var val: [Any] = []
            if values.count > 0 {
                for value in values {
                    if let obj = value as? String {
                        let str: String =
                            "\(String(describing: obj))"
                        val.append(str)
                    } else if let obj = value as? Int {
                        val.append(obj)
                    } else if let obj = value as? Float {
                        val.append(obj)
                    } else if let obj = value as? Double {
                        val.append(obj)
                    } else if value is NSNull {
                        val.append(value)
                    } else if let obj = value as? [String: Any] {
                        if var keys = Array(obj.keys) as? [String] {
                            if #available(iOS 15.0, *) {
                                keys.sort(using: .localizedStandard)
                                var valuesArr: [UInt8] = []
                                for key in keys {
                                    if let mVal = obj[key] {
                                        if let iVal = mVal as? Int {
                                            valuesArr.append(UInt8(iVal))
                                        } else {
                                            let msg: String = "Error in reading buffer"
                                            throw CapacitorSQLiteError.failed(message: msg)
                                        }
                                    } else {
                                        let msg: String = "Error in reading buffer"
                                        throw CapacitorSQLiteError.failed(message: msg)
                                    }
                                }
                                val.append(valuesArr)
                            } else {
                                let msg: String = "Error buffer sorted not implemented"
                                throw CapacitorSQLiteError.failed(message: msg)

                            }
                        }
                    } else {
                        let msg: String = "Not a SQL type"
                        throw CapacitorSQLiteError.failed(message: msg)
                    }
                }
            }
            let res = try mDb.runSQL(sql: statement, values: val,
                                     transaction: transaction)
            return res
        } catch DatabaseError.runSQL(let message) {
            throw CapacitorSQLiteError.failed(message: message)
        } catch let error {
            let msg: String = "\(error)"
            throw CapacitorSQLiteError.failed(message: msg)
        }
    }
    // swiftlint:enable cyclomatic_complexity
    // swiftlint:enable function_body_length

    // MARK: - Query

    @objc func query(_ dbName: String, statement: String,
                     values: [Any]) throws -> [[String: Any]] {
        let mDb = try getOpenConnection(dbName)
        do {
            let res: [[String: Any]] = try mDb
                .selectSQL(sql: statement, values: values)
            return res
        } catch DatabaseError.selectSQL(let message) {
            throw CapacitorSQLiteError.failed(message: message)
        } catch let error {
            let msg: String = "\(error)"
            throw CapacitorSQLiteError.failed(message: msg)
        }
    }

    // MARK: - isDBOpen

    @objc func isDBOpen(_ dbName: String) throws -> NSNumber {
        let mDb = try getConnection(dbName)
        return mDb.isDBOpen() ? 1 : 0
    }

    // MARK: - isJsonValid

    @objc func isJsonValid(_ parsingData: String) throws {
        guard isInit else {
            throw CapacitorSQLiteError.failed(message: initMessage)
        }
        _ = try CapacitorSQLite.decodeJsonSQLite(parsingData)
    }

    // MARK: - importFromJson

    // swiftlint:disable function_body_length
    @objc func importFromJson(_ parsingData: String)
    throws -> [String: Int] {
        guard isInit else {
            throw CapacitorSQLiteError.failed(message: initMessage)
        }
        let jsonSQLite = try CapacitorSQLite.decodeJsonSQLite(parsingData)
        let version: Int = jsonSQLite.version
        var dbName: String = CapacitorSQLite.getDatabaseName(
            dbName: jsonSQLite.database
        )
        dbName.append("SQLite.db")
        // open the database
        let mDb: Database
        do {
            mDb = try Database(
                databaseLocation: databaseLocation, databaseName: dbName,
                version: version)
            if jsonSQLite.overwrite ?? false {
                let isExists = UtilsFile
                    .isFileExist(databaseLocation: databaseLocation,
                                 fileName: dbName)
                if isExists {
                    _ = try UtilsFile
                        .deleteFile(fileName: dbName,
                                    databaseLocation: databaseLocation)
                }
            }
            try mDb.open()
        } catch UtilsFileError.deleteFileFailed {
            let message = "Delete Database failed"
            throw CapacitorSQLiteError.failed(message: message)
        } catch DatabaseError.open(let message) {
            throw CapacitorSQLiteError.failed(message: message)
        } catch let error {
            let msg: String = "\(error)"
            throw CapacitorSQLiteError.failed(message: msg)
        }
        // check if the database as some tables
        do {
            let tableList: [String] = try mDb.getTableNames()
            if tableList.count > 0 {
                let curVersion = try mDb.getVersion()
                if version < curVersion {
                    var msg: String = "ImportFromJson: Cannot import a "
                    msg += "version lower than \(curVersion)"
                    throw CapacitorSQLiteError.failed(message: msg)
                }
                if curVersion == version {
                    try mDb.close()
                    return ["changes": 0]
                }
            }

        } catch DatabaseError.getTableNames(let message) {
            throw CapacitorSQLiteError.failed(message: message)
        } catch let error {
            let msg: String = "\(error)"
            throw CapacitorSQLiteError.failed(message: msg)
        }
        // import from Json Object
        do {
            let res: [String: Int] = try mDb
                .importFromJson(jsonSQLite: jsonSQLite)
            try mDb.close()
            if let result = res["changes"] {
                if result < 0 {
                    let msg: String = "changes < 0"
                    throw CapacitorSQLiteError
                    .failed(message: msg)
                } else {
                    return res
                }
            } else {
                let msg: String = "changes not found"
                throw CapacitorSQLiteError.failed(message: msg)
            }
        } catch DatabaseError.importFromJson(let message) {
            var msg = message
            do {
                try mDb.close()
                throw CapacitorSQLiteError.failed(message: msg)
            } catch DatabaseError.close(let message) {
                msg.append(" \(message)")
                throw CapacitorSQLiteError.failed(message: msg)
            }
        } catch DatabaseError.close(let message) {
            throw CapacitorSQLiteError.failed(message: message)
        }
    }
    // swiftlint:enable function_body_length

    // MARK: - exportToJson

    @objc func exportToJson(_ dbName: String) throws -> [String: Any] {
        let mDb = try getOpenConnection(dbName)
        do {
            let res: [String: Any] = try mDb.exportToJson()
            if res.count == 0 {
                var msg: String = "return Object is empty "
                msg.append("No data to synchronize")
                throw CapacitorSQLiteError.failed(message: msg)
            }
            return res
        } catch DatabaseError.exportToJson(let message) {
            throw CapacitorSQLiteError.failed(message: message)
        }
    }

    class func getDatabaseName(dbName: String) -> String {
        var retName: String = dbName
        if !retName.contains("/") {
            if retName.suffix(3) == ".db" {
                retName = String(retName.dropLast(3))
            }
        }
        return retName
    }

    class func decodeJsonSQLite(_ parsingData: String) throws -> JsonSQLite {
        guard let data = ("["+parsingData+"]").data(using: .utf8) else {
            let msg: String = "Stringify Json Object not Valid"
            throw CapacitorSQLiteError.failed(message: msg)
        }
        let jsonSQLite: JsonSQLite
        do {
            jsonSQLite = try JSONDecoder().decode([JsonSQLite].self, from: data)[0]
        } catch let error {
            throw CapacitorSQLiteError.failed(message: "Stringify Json Object not Valid \(error)")
        }
        if let mode = jsonSQLite.mode, mode != "full" {
            throw CapacitorSQLiteError.failed(message: "Json mode '\(mode)' not supported, only 'full'")
        }
        return jsonSQLite
    }

    func closeAllConnections() throws {
        for (key, mDb) in dbDict {
            if mDb.isDBOpen() {
                do {
                    try mDb.close()
                } catch DatabaseError.close(let message) {
                    throw CapacitorSQLiteError.failed(message: message)
                }
            }
            dbDict.removeValue(forKey: key)
        }
    }

    private func getConnection(_ dbName: String) throws -> Database {
        guard isInit else {
            throw CapacitorSQLiteError.failed(message: initMessage)
        }
        let mDbName = CapacitorSQLite.getDatabaseName(dbName: dbName)
        guard let mDb: Database = dbDict[mDbName] else {
            let msg = "Connection to \(mDbName) not available"
            throw CapacitorSQLiteError.failed(message: msg)
        }
        return mDb
    }

    private func getOpenConnection(_ dbName: String) throws -> Database {
        let mDb = try getConnection(dbName)
        if !mDb.isDBOpen() {
            let mDbName = CapacitorSQLite.getDatabaseName(dbName: dbName)
            throw CapacitorSQLiteError.failed(message: "Database \(mDbName) not opened")
        }
        return mDb
    }
}
// swiftlint:enable type_body_length
// swiftlint:enable file_length
