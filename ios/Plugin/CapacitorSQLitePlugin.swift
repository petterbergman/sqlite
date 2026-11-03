import Foundation
import Capacitor

@objc(CapacitorSQLitePlugin)
// swiftlint:disable type_body_length
public class CapacitorSQLitePlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "CapacitorSQLitePlugin"
    public let jsName = "CapacitorSQLite"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "createConnection", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "closeConnection", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "open", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "close", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "execute", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "executeSet", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "run", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "query", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "isDBOpen", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "importFromJson", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "isJsonValid", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "exportToJson", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "isDatabase", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "checkConnectionsConsistency", returnType: CAPPluginReturnPromise)
    ]

    private var implementation: CapacitorSQLite?
    private let retHandler: ReturnHandler = ReturnHandler()

    override public func load() {
        var config = SqliteConfig()
        config.iosDatabaseLocation = getConfig().getString("iosDatabaseLocation")
        self.implementation = CapacitorSQLite(config: config)
    }

    // MARK: - CreateConnection

    @objc func createConnection(_ call: CAPPluginCall) {
        guard let dbName = call.options["database"] as? String else {
            retHandler.rResult(
                call: call,
                message: "CreateConnection: Must provide a database name")
            return
        }
        let version: Int = call.getInt("version") ?? 1
        do {
            try implementation?.createConnection(dbName, version: version)
            retHandler.rResult(call: call)
            return
        } catch CapacitorSQLiteError.failed(let message) {
            let msg = "CreateConnection: \(message)"
            retHandler.rResult(call: call, message: msg)
            return
        } catch let error {
            retHandler.rResult(
                call: call,
                message: "CreateConnection: \(error)")
            return
        }
    }

    // MARK: - Open

    @objc func open(_ call: CAPPluginCall) {
        guard let dbName = call.options["database"] as? String else {
            retHandler.rResult(
                call: call,
                message: "Open: Must provide a database name")
            return
        }
        do {
            try implementation?.open(dbName)
            retHandler.rResult(call: call)
            return
        } catch CapacitorSQLiteError.failed(let message) {
            let msg = "Open: \(message)"
            retHandler.rResult(call: call, message: msg)
            return
        } catch let error {
            retHandler.rResult(
                call: call,
                message: "Open: \(error)")
            return
        }
    }

    // MARK: - Close

    @objc func close(_ call: CAPPluginCall) {
        guard let dbName = call.options["database"] as? String else {
            retHandler.rResult(
                call: call,
                message: "Close: Must provide a database name")
            return
        }
        do {
            try implementation?.close(dbName)
            retHandler.rResult(call: call)
            return
        } catch CapacitorSQLiteError.failed(let message) {
            let msg = "Close: \(message)"
            retHandler.rResult(call: call, message: msg)
            return
        } catch let error {
            retHandler.rResult(
                call: call,
                message: "Close: \(error)")
            return
        }
    }

    // MARK: - Close Connection

    @objc func closeConnection(_ call: CAPPluginCall) {
        guard let dbName = call.options["database"] as? String else {
            retHandler.rResult(
                call: call,
                message: "CloseConnection: Must provide a database name")
            return
        }
        do {
            try implementation?.closeConnection(dbName)
            retHandler.rResult(call: call)
            return
        } catch CapacitorSQLiteError.failed(let message) {
            let msg = "CloseConnection: \(message)"
            retHandler.rResult(call: call, message: msg)
            return
        } catch let error {
            retHandler.rResult(
                call: call,
                message: "CloseConnection: \(error)")
            return
        }

    }

    // MARK: - CheckConsistency

    @objc func checkConnectionsConsistency(_ call: CAPPluginCall) {
        guard let dbNames = call.options["dbNames"] as? [String] else {
            retHandler.rResult(
                call: call,
                message: "CheckConnectionsConsistency: Must provide a " +
                    "Connection Array")
            return
        }
        do {
            let res = try implementation?.checkConnectionsConsistency(dbNames)
            retHandler.rResult(call: call, ret: res == 1)
            return
        } catch let error {
            retHandler.rResult(
                call: call,
                message: "CheckConnectionsConsistency: \(error)")
            return
        }
    }

    // MARK: - IsDatabase

    @objc func isDatabase(_ call: CAPPluginCall) {
        guard let dbName = call.options["database"] as? String else {
            retHandler.rResult(
                call: call, ret: false,
                message: "isDatabase: Must provide a database name")
            return
        }
        do {
            let res = try implementation?.isDatabase(dbName)
            retHandler.rResult(call: call, ret: res == 1)
        } catch CapacitorSQLiteError.failed(let message) {
            let msg = "isDatabase: \(message)"
            retHandler.rResult(call: call, message: msg)
            return
        } catch let error {
            retHandler.rResult(
                call: call,
                message: "isDatabase: \(error)")
            return
        }

    }

    // MARK: - Execute

    @objc func execute(_ call: CAPPluginCall) {

        guard let dbName = call.options["database"] as? String else {
            retHandler.rChanges(
                call: call, ret: ["changes": -1],
                message: "Execute: Must provide a database name")
            return
        }
        let statements: String = call.getString("statements") ?? ""
        let transaction: Bool = call.getBool("transaction") ?? true
        if statements.count == 0 {
            let msg: String = "Execute: Must provide raw SQL statements"
            retHandler.rChanges(
                call: call, ret: ["changes": -1],
                message: msg)
            return
        }
        do {
            if let res = try implementation?
                .execute(dbName, statements: statements,
                         transaction: transaction) {
                retHandler.rChanges(call: call, ret: res)
                return
            } else {
                retHandler.rChanges(
                    call: call, ret: ["changes": -1],
                    message: "Execute: Does not return a valid execute")
                return
            }
        } catch CapacitorSQLiteError.failed(let message) {
            retHandler.rChanges(
                call: call, ret: ["changes": -1],
                message: "Execute: \(message)")
            return
        } catch let error {
            retHandler.rChanges(
                call: call, ret: ["changes": -1],
                message: "Execute: \(error)")
            return
        }

    }

    // MARK: - ExecuteSet
    // swiftlint:disable function_body_length
    @objc func executeSet(_ call: CAPPluginCall) {
        guard let dbName = call.options["database"] as? String else {
            retHandler.rChanges(
                call: call, ret: ["changes": -1],
                message: "ExecuteSet: Must provide a database name")
            return
        }
        guard let set = call.options["set"] as? [[String: Any]] else {
            var msg: String = "ExecuteSet: "
            msg.append("Must provide a set of SQL statements")
            retHandler.rChanges(
                call: call, ret: ["changes": -1], message: msg)
            return

        }
        if set.count == 0 {
            var msg: String = "ExecuteSet: Must "
            msg.append("provide a non-empty set of SQL statements")
            retHandler.rChanges(call: call, ret: ["changes": -1],
                                message: msg)
            return
        }
        for dict in set {
            let keys = dict.keys
            if !(keys.contains("statement")) ||
                !(keys.contains("values")) {
                var msg: String = "ExecuteSet: "
                msg.append("Must provide a set as Array of ")
                msg.append("{statement,values}")
                retHandler.rChanges(call: call, ret: ["changes": -1],
                                    message: msg)
                return
            }
        }
        let transaction: Bool = call.getBool("transaction") ?? true
        do {
            if let res = try implementation?.executeSet(dbName, set: set,
                                                        transaction: transaction) {
                retHandler.rChanges(call: call, ret: res)
                return
            } else {
                retHandler.rChanges(
                    call: call, ret: ["changes": -1],
                    message: "ExecuteSet: Does not return a valid executeSet")
                return

            }
        } catch CapacitorSQLiteError.failed(let message) {
            retHandler.rChanges(
                call: call, ret: ["changes": -1],
                message: "ExecuteSet: \(message)")
            return
        } catch let error {
            retHandler.rChanges(
                call: call, ret: ["changes": -1],
                message: "ExecuteSet: \(error)")
            return
        }

    }
    // swiftlint:enable function_body_length

    // MARK: - Run

    @objc func run(_ call: CAPPluginCall) {
        guard let dbName = call.options["database"] as? String else {
            retHandler.rChanges(
                call: call, ret: ["changes": -1],
                message: "Run: Must provide a database name")
            return
        }
        guard let statement = call.options["statement"]
                as? String else {
            let msg: String =
                "Run: Must provide a SQL statement"
            retHandler.rChanges(call: call,
                                ret: ["changes": -1],
                                message: msg)
            return
        }
        guard let values = call.options["values"]
                as? [Any] else {
            retHandler.rChanges(
                call: call, ret: ["changes": -1],
                message: "Run: Must provide an Array of values")
            return
        }
        let transaction: Bool = call.getBool("transaction") ?? true
        do {
            if let res = try
                implementation?.run(dbName,
                                    statement: statement,
                                    values: values,
                                    transaction: transaction) {
                retHandler.rChanges(call: call, ret: res)
                return
            } else {
                retHandler.rChanges(
                    call: call, ret: ["changes": -1],
                    message: "Run: Does not return a valid run")
                return
            }
        } catch CapacitorSQLiteError.failed(let message) {
            retHandler.rChanges(
                call: call, ret: ["changes": -1],
                message: "Run: \(message)")
            return
        } catch let error {
            retHandler.rChanges(
                call: call, ret: ["changes": -1],
                message: "Run: \(error)")
            return
        }

    }

    // MARK: - Query

    @objc func query(_ call: CAPPluginCall) {
        guard let dbName = call.options["database"]
                as? String else {
            var msg: String = "Query: "
            msg.append("Must provide a database name")
            retHandler.rValues(call: call, ret: [],
                               message: msg)
            return
        }

        guard let statement = call.options["statement"]
                as? String else {
            var msg: String = "Query: "
            msg.append("Must provide a query statement")
            retHandler.rValues(call: call, ret: [],
                               message: msg)
            return
        }
        guard let values = call.options["values"] as? [Any] else {
            var msg: String = "Query: "
            msg.append("Must provide an Array of value")
            retHandler.rValues(call: call, ret: [],
                               message: msg)
            return

        }
        do {
            if let res: [[String: Any]] = try
                implementation?.query(dbName,
                                      statement: statement,
                                      values: values) {
                retHandler.rValues(call: call, ret: res)
                return
            } else {
                retHandler.rValues(
                    call: call, ret: [],
                    message: "Query: Does not return a valid query")
                return

            }
        } catch CapacitorSQLiteError.failed(let message) {
            retHandler.rValues(
                call: call, ret: [],
                message: "Query: \(message)")
            return
        } catch let error {
            retHandler.rValues(
                call: call, ret: [],
                message: "Query: \(error)")
            return
        }

    }

    // MARK: - IsDBOpen

    @objc func isDBOpen(_ call: CAPPluginCall) {
        guard let dbName = call.options["database"] as? String else {
            retHandler.rResult(
                call: call, ret: false,
                message: "idDBOpen: Must provide a database name")
            return
        }
        do {
            let res = try implementation?.isDBOpen(dbName)
            retHandler.rResult(call: call, ret: res == 1)
            return
        } catch CapacitorSQLiteError.failed(let message) {
            let msg = "isDBOpen: \(message)"
            retHandler.rResult(call: call, message: msg)
            return
        } catch let error {
            retHandler.rResult(
                call: call,
                message: "isDBOpen: \(error)")
            return
        }
    }

    // MARK: - IsJsonValid

    @objc func isJsonValid(_ call: CAPPluginCall) {
        let parsingData: String = call.getString("jsonstring") ?? ""
        if parsingData.count == 0 {
            var msg: String = "IsJsonValid: "
            msg.append("Must provide a Stringify Json Object")
            retHandler.rResult(call: call, message: msg)
            return
        }
        do {
            try implementation?.isJsonValid(parsingData)
            retHandler.rResult(call: call, ret: true)
            return
        } catch CapacitorSQLiteError.failed(let message) {
            let msg = "isJsonValid: \(message)"
            retHandler.rResult(call: call, message: msg)
            return
        } catch let error {
            let msg = "isJsonValid: \(error)"
            retHandler.rResult(call: call, message: msg)
            return
        }
    }

    // MARK: - ImportFromJson

    @objc func importFromJson(_ call: CAPPluginCall) {
        let parsingData: String = call.getString("jsonstring") ?? ""
        if parsingData.count == 0 {
            retHandler.rChanges(call: call, ret: ["changes": -1],
                                message: "ImportFromJson: " +
                                    "Must provide a Stringify Json Object")
            return
        }
        do {
            let res: [String: Int]  = try implementation?
                .importFromJson(parsingData) ?? ["changes": -1]
            retHandler.rChanges(call: call, ret: res)
            return
        } catch CapacitorSQLiteError.failed(let message) {
            retHandler.rChanges(
                call: call, ret: ["changes": -1],
                message: "importFromJson: \(message)")
            return
        } catch let error {
            let msg = "importFromJson: " +
                "\(error)"
            retHandler.rChanges(
                call: call, ret: ["changes": -1],
                message: msg)
            return
        }

    }

    // MARK: - ExportToJson

    @objc func exportToJson(_ call: CAPPluginCall) {
        guard let dbName = call.options["database"]
                as? String else {
            let msg = "ExportToJson: Must provide a database name"
            retHandler.rJsonSQLite(call: call, ret: [:],
                                   message: msg)
            return
        }
        do {
            let res: [String: Any] = try implementation?
                .exportToJson(dbName) ?? [:]
            retHandler.rJsonSQLite(call: call, ret: res)
            return
        } catch CapacitorSQLiteError.failed(let message) {
            let msg = "exportToJson: \(message)"
            retHandler.rJsonSQLite(call: call, ret: [:],
                                   message: msg)
            return
        } catch let error {
            let msg = "exportToJson: \(error)"
            retHandler.rJsonSQLite(call: call, ret: [:],
                                   message: msg)
            return
        }

    }
}
// swiftlint:enable type_body_length
