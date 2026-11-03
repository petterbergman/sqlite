//
//  ExportToJson.swift
//  Plugin
//
//  Created by  Quéau Jean Pierre on 18/01/2021.
//  Copyright © 2021 Max Lynch. All rights reserved.
//

import Foundation
import SQLite3

// swiftlint:disable type_body_length
// swiftlint:disable file_length
enum ExportToJsonError: Error {
    case createExportObject(message: String)
    case getTablesFull(message: String)
    case getSchemaIndexes(message: String)
    case getValues(message: String)
    case createIndexes(message: String)
    case createTriggers(message: String)
    case createSchema(message: String)
    case createValues(message: String)
    case createRowValues(message: String)
    case modEmbeddedParentheses(message: String)
    case getViews(message: String)
}
var REALAFFINITY: [String] = ["REAL", "DOUBLE", "DOUBLE PRECISION", "FLOAT"]
var INTEGERAFFINITY: [String] = ["INTEGER", "INT", "TINYINT", "SMALLINT",
                                 "MEDIUMINT", "BIGINT", "UNSIGNED BIG INT",
                                 "INT2", "INT8"]
var TEXTAFFINITY: [String] = ["TEXT", "CHARACTER", "VARCHAR", "VARYING CHARACTER",
                              "NCHAR", "NATIVE CHARACTER", "NVARCHAR", "CLOB"]
var BLOBAFFINITY: [String] = ["BLOB"]
var NUMERICAFFINITY: [String] = ["NUMERIC", "DECIMAL", "BOOLEAN", "DATE",
                                 "DATETIME"]
class ExportToJson {
    // MARK: - ExportToJson - CreateExportObject

    class func createExportObject(mDB: Database, dbName: String,
                                  version: Int)
    throws -> [String: Any] {
        var retObj: [String: Any] = [:]
        var views: [[String: String]] = []
        var tables: [[String: Any]] = []
        do {
            // Get the views
            // get the view's name
            var stmtV: String = "SELECT name,sql FROM sqlite_master WHERE "
            stmtV.append("type = 'view' AND name NOT LIKE 'sqlite_%';")
            var resViews =  try UtilsSQLCipher.querySQL(
                mDB: mDB, sql: stmtV, values: [])
            if resViews.count > 1 {
                resViews.removeFirst()
                views = try ExportToJson
                    .getViews(mDB: mDB,
                              resViews: resViews)
            }
            // Get the tables

            // get the table's name
            var query: String = "SELECT name,sql FROM sqlite_master WHERE "
            query.append("type = 'table' AND name NOT LIKE 'sqlite_%';")
            var resTables =  try UtilsSQLCipher.querySQL(
                mDB: mDB, sql: query, values: [])
            if resTables.count > 1 {
                resTables.removeFirst()
                tables = try ExportToJson.getTablesFull(mDB: mDB,
                                                        resTables: resTables)
            }
        } catch UtilsSQLCipherError.querySQL(let message) {
            throw ExportToJsonError.createExportObject(
                message: "Error get table's names failed : \(message)")
        } catch ExportToJsonError.getViews(let message) {
            throw ExportToJsonError.createExportObject(
                message: "Error get views failed : \(message)")
        } catch ExportToJsonError.getTablesFull(let message) {
            throw ExportToJsonError.createExportObject(
                message: "Error get tables failed : \(message)")
        }
        if tables.count > 0 {
            retObj["database"] = dbName.dropLast(9)
            retObj["version"] = version
            retObj["tables"] = tables
            if views.count > 0 {
                retObj["views"] = views
            }
        }

        return retObj
    }

    // MARK: - ExportToJson - GetSchemaIndexes

    // swiftlint:disable function_body_length
    // swiftlint:disable cyclomatic_complexity
    class func getSchemaIndexes(mDB: Database,
                                stmt: String, table: [String: Any] )
    throws -> [String: Any] {
        var retTable: [String: Any] = table
        var isSchema: Bool  = false
        var isIndexes: Bool = false
        var isTriggers: Bool = false
        do {
            // create schema
            let schema: [[String: String]] = try
                ExportToJson.createSchema(stmt: stmt)
            if schema.count > 0 {
                isSchema = try UtilsJson.validateSchema(schema: schema)
                if isSchema {retTable["schema"] = schema}
            }
            // create indexes
            guard let tableName: String = table["name"] as? String
            else {
                var message: String = "Error getSchemaIndexes: did not"
                message.append("find table name")
                throw ExportToJsonError.getSchemaIndexes(
                    message: message)
            }
            let indexes: [[String: String]] = try
                ExportToJson.createIndexes(mDB: mDB,
                                           tableName: tableName)
            if indexes.count > 0 {
                isIndexes = try UtilsJson.validateIndexes(
                    indexes: indexes)
                if isIndexes {retTable["indexes"] = indexes}
            }
            // create triggers
            let triggers: [[String: String]] = try
                ExportToJson.createTriggers(mDB: mDB,
                                            tableName: tableName)
            if triggers.count > 0 {
                isTriggers = try UtilsJson.validateTriggers(
                    triggers: triggers)
                if isTriggers {retTable["triggers"] = triggers}
            }
            let retObj: [String: Any] = ["isSchema": isSchema,
                                         "isIndexes": isIndexes,
                                         "isTriggers": isTriggers,
                                         "table": retTable]
            return retObj
        } catch ExportToJsonError.createSchema(let message) {
            throw ExportToJsonError.getSchemaIndexes(message: message)
        } catch UtilsJsonError.validateSchema(let message) {
            throw ExportToJsonError.getSchemaIndexes(message: message)
        } catch ExportToJsonError.createIndexes(let message) {
            throw ExportToJsonError.getSchemaIndexes(message: message)
        } catch UtilsJsonError.validateIndexes(let message) {
            throw ExportToJsonError.getSchemaIndexes(message: message)
        } catch ExportToJsonError.createTriggers(let message) {
            throw ExportToJsonError.getSchemaIndexes(message: message)
        } catch UtilsJsonError.validateTriggers(let message) {
            throw ExportToJsonError.getSchemaIndexes(message: message)
        }
    }
    // swiftlint:enable cyclomatic_complexity
    // swiftlint:enable function_body_length

    // MARK: - ExportToJson - GetValues

    class func getValues(mDB: Database, stmt: String,
                         table: [String: Any] )
    throws -> [String: Any] {
        var retTable: [String: Any] = table
        var isValues: Bool  = false
        do {
            guard let tableName: String = table["name"] as? String
            else {
                var message: String = "Error getSchemaIndexes: did "
                message.append("not find table name")
                throw ExportToJsonError.getValues(message: message)
            }
            let jsonNamesTypes: JsonNamesTypes = try UtilsJson
                .getTableColumnNamesTypes(mDB: mDB,
                                          tableName: tableName)
            let rowNames = jsonNamesTypes.names
            let rowTypes = jsonNamesTypes.types

            // create the table data
            let values: [[Any]] = try ExportToJson
                .createValues(mDB: mDB, query: stmt, names: rowNames,
                              types: rowTypes)
            if values.count > 0 {
                retTable["values"] = values
                isValues = true
            }
            let retObj: [String: Any] = ["isValues": isValues,
                                         "table": retTable]
            return retObj
        } catch UtilsJsonError.getTableColumnNamesTypes(let message) {
            throw ExportToJsonError.getValues(message: message)
        } catch ExportToJsonError.createValues(let message) {
            throw ExportToJsonError.getValues(message: message)
        }
    }

    // MARK: - ExportToJson - GetViews

    class func getViews(mDB: Database,
                        resViews: [[String: Any]])
    throws -> [[String: String]] {
        var views: [[String: String]] = []
        var iView: Int = 0
        for rView in resViews {
            iView += 1
            guard let viewName: String = rView["name"] as? String
            else {
                throw ExportToJsonError.getViews(
                    message: "Error did not find view name")
            }
            guard let sqlStmt: String = rView["sql"] as? String else {
                throw ExportToJsonError.getViews(
                    message: "Error did not find sql statement")
            }
            var view: [String: String] = [:]
            view["name"] = viewName
            view["value"] = sqlStmt.components(separatedBy: "AS ")[1]
            views.append(view)
        }
        return views
    }

    // MARK: - ExportToJson - GetTablesFull

    // swiftlint:disable cyclomatic_complexity
    // swiftlint:disable function_body_length
    class func getTablesFull(mDB: Database,
                             resTables: [[String: Any]])
    throws -> [[String: Any]] {
        var tables: [[String: Any]] = []
        for rTable in resTables {
            guard let tableName: String = rTable["name"] as? String
            else {
                throw ExportToJsonError.getTablesFull(
                    message: "Error did not find table name")
            }
            guard let sqlStmt: String = rTable["sql"] as? String else {
                throw ExportToJsonError.getTablesFull(
                    message: "Error did not find sql statement")
            }
            var table: [String: Any] = [:]
            table["name"] = tableName
            var result: [String: Any] = [:]
            do {
                // create schema and indexes
                result = try ExportToJson
                    .getSchemaIndexes(mDB: mDB,
                                      stmt: sqlStmt, table: table)
                guard let isSchema: Bool = result["isSchema"] as? Bool
                else {
                    throw ExportToJsonError.getTablesFull(
                        message: "Error did not find isSchema")
                }
                // this seems not correct as it can be case without index
                guard let isIndexes: Bool = result["isIndexes"] as? Bool
                else {
                    throw ExportToJsonError.getTablesFull(
                        message: "Error did not find isIndexes")
                }
                guard let retTable: [String: Any] =
                        result["table"] as? [String: Any] else {
                    throw ExportToJsonError.getTablesFull(
                        message: "Error did not find table")
                }
                table = retTable
                // create the table data
                let query: String = "SELECT * FROM \(tableName);"
                result = try ExportToJson
                    .getValues(mDB: mDB, stmt: query,
                               table: table)
                guard let isValues: Bool = result["isValues"] as? Bool
                else {
                    throw ExportToJsonError.getTablesFull(
                        message: "Error did not find isValues")
                }
                guard let retTable1: [String: Any] = result["table"]
                        as? [String: Any] else {
                    throw ExportToJsonError.getTablesFull(
                        message: "Error did not find table")
                }
                table = retTable1
                // check the table object validity
                var tableKeys: [String] = []
                tableKeys.append(contentsOf: table.keys)

                if tableKeys.count <= 1 ||
                    (!isSchema && !isIndexes && !isValues) {
                    throw ExportToJsonError.getTablesFull(
                        message: "Error table \(tableName) is not a jsonTable")
                }
                tables.append(table)
            } catch ExportToJsonError.getSchemaIndexes(let message) {
                throw ExportToJsonError.getTablesFull(
                    message: message)
            } catch ExportToJsonError.getValues(let message) {
                throw ExportToJsonError.getTablesFull(
                    message: message)
            }
        }
        return tables
    }
    // swiftlint:enable function_body_length
    // swiftlint:enable cyclomatic_complexity

    // MARK: - ExportToJson - ModEmbeddedParentheses

    class func modEmbeddedParentheses(sqlStmt: String) throws -> String {
        let stmt: String = sqlStmt
        let oPars: [Int] = stmt.indicesOf(string: "(")
        let cPars: [Int] = stmt.indicesOf(string: ")")
        if oPars.count != cPars.count {
            let msg: String = "Not same number of " +
                "opening and closing parentheses"
            throw ExportToJsonError.modEmbeddedParentheses(
                message: msg)
        }
        if oPars.count == 0 {
            return stmt
        }

        var resStmt: String = String(stmt.stringRange(fromIdx: 0, toIdx: oPars[0]))
        var ipos = 0
        while ipos < oPars.count {
            var str: String
            if ipos < oPars.count - 1 {
                if oPars[ipos+1] < cPars[ipos] {
                    str = String(stmt.stringRange(fromIdx: oPars[ipos],
                                                  toIdx: cPars[ipos + 1] + 1))
                    ipos += 1
                } else {
                    str = String(stmt.stringRange(fromIdx: oPars[ipos],
                                                  toIdx: cPars[ipos] + 1))
                }
            } else {
                str = String(stmt.stringRange(fromIdx: oPars[ipos],
                                              toIdx: cPars[ipos] + 1))
            }
            let mStmt: String = str.replacingOccurrences(of: ",", with: "§")
            resStmt.append(mStmt)
            if ipos < oPars.count - 1 {
                resStmt.append(String(stmt.stringRange(fromIdx: cPars[ipos] + 1,
                                                       toIdx: oPars[ipos + 1])))
            }
            ipos += 1
        }
        resStmt.append(String(stmt.stringRange(fromIdx: cPars[cPars.count - 1] + 1,
                                               toIdx: stmt.count)))
        return resStmt

    }

    // MARK: - ExportToJson - SplitFirstWord

    // split on the first run of any whitespace (spaces, tabs, \r)
    class func splitFirstWord<S: StringProtocol>(_ str: S) -> [Substring] {
        return str.split(maxSplits: 1, whereSeparator: { $0.isWhitespace })
            .map { Substring($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    // MARK: - ExportToJson - CreateSchema

    // swiftlint:disable function_body_length
    // swiftlint:disable cyclomatic_complexity
    class func createSchema(stmt: String) throws -> [[String: String]] {
        var retSchema: [[String: String]] = []
        // get the sqlStmt between the parenthesis sqlStmt
        if let openPar = stmt.firstIndex(of: "(") {
            if let closePar = stmt.lastIndex(of: ")") {
                var sqlStmt: String = String(
                    stmt[stmt.index(after: openPar)..<closePar])
                // check if there is other parenthesis and replace the ',' by '§'
                do {
                    sqlStmt = try modEmbeddedParentheses(sqlStmt: sqlStmt)
                    let sch: [String] = sqlStmt.components(separatedBy: ",")
                    for ipos in 0..<sch.count {
                        let rstr: String = sch[ipos]
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        var row = ExportToJson.splitFirstWord(rstr)
                        if  row.count == 2 {
                            var columns: [String: String] = [:]
                            switch String(row[0]).uppercased() {
                            case "FOREIGN":
                                guard let oPar = rstr.firstIndex(of: "(")
                                else {
                                    var msg: String = "Create Schema "
                                    msg.append("FOREIGN KEYS no '('")
                                    throw ExportToJsonError
                                    .createSchema(message: msg)
                                }
                                guard let cPar = rstr.firstIndex(of: ")")
                                else {
                                    var msg: String = "Create Schema "
                                    msg.append("FOREIGN KEYS no ')'")
                                    throw ExportToJsonError
                                    .createSchema(message: msg)
                                }
                                row[0] = rstr[rstr.index(
                                                after: oPar)..<cPar]
                                row[1] = rstr[rstr.index(cPar,
                                                         offsetBy: 2)..<rstr.endIndex]
                                columns["foreignkey"] = String(row[0])
                                    .replacingOccurrences(of: "§",
                                                          with: ",")
                                    .replacingOccurrences(of: ", ",
                                                          with: ",")
                            case "PRIMARY", "UNIQUE":
                                let prefix = (String(row[0]).uppercased() == "PRIMARY") ? "CPK_" : "CUN_"

                                guard let oPar = rstr.firstIndex(of: "(")
                                else {
                                    var msg: String = "Create Schema "
                                    msg.append("PRIMARY/UNIQUE KEY no '('")
                                    throw ExportToJsonError
                                    .createSchema(message: msg)
                                }
                                guard let cPar = rstr.firstIndex(of: ")")
                                else {
                                    var msg: String = "Create Schema "
                                    msg.append("PRIMARY/UNIQUE KEY no ')'")
                                    throw ExportToJsonError
                                    .createSchema(message: msg)
                                }
                                row[0] = rstr[rstr.index(
                                                after: oPar)..<cPar]
                                row[1] = rstr[rstr.index(rstr.startIndex,
                                                         offsetBy: 0)..<rstr.endIndex]
                                columns["constraint"] = prefix + String(row[0])
                                    .replacingOccurrences(of: "§",
                                                          with: "_")
                                    .replacingOccurrences(of: "_ ",
                                                          with: "_")
                            case "CONSTRAINT":
                                let tRow = ExportToJson.splitFirstWord(row[1])
                                row[0] = tRow[0]
                                columns["constraint"] = String(row[0])
                                row[1] = tRow[1]
                            default:
                                columns["column"] =  String(row[0])
                            }
                            columns["value"] = String(row[1]).replacingOccurrences(of: "§", with: ",")
                            retSchema.append(columns)
                        } else {
                            throw ExportToJsonError.createSchema(
                                message: "Query result not well formatted")
                        }
                    }

                } catch ExportToJsonError.modEmbeddedParentheses(let message) {
                    throw ExportToJsonError.createIndexes(
                        message: "Error modEmbeddedParentheses failed : \(message)")
                }
            } else {
                throw ExportToJsonError.createSchema(
                    message: "No ')' in the query result")
            }
        } else {
            throw ExportToJsonError.createSchema(
                message: "No '(' in the query result")
        }
        return retSchema
    }
    // swiftlint:enable cyclomatic_complexity
    // swiftlint:enable function_body_length

    // MARK: - ExportToJson - CreateIndexes

    // swiftlint:disable function_body_length
    // swiftlint:disable cyclomatic_complexity
    class func createIndexes(mDB: Database, tableName: String)
    throws -> [[String: String]] {
        var retIndexes: [[String: String]] = []
        var query = "SELECT name,tbl_name,sql FROM sqlite_master WHERE "
        query.append("type = 'index' AND tbl_name = '\(tableName)' ")
        query.append("AND sql NOTNULL;")
        do {
            var resIndexes =  try UtilsSQLCipher.querySQL(
                mDB: mDB, sql: query, values: [])
            if resIndexes.count > 1 {
                resIndexes.removeFirst()
                for ipos in 0..<resIndexes.count {
                    var row: [String: String] = [:]
                    let keys: [String] = Array(resIndexes[ipos].keys)
                    if keys.count == 3 {
                        guard let tblName =
                                resIndexes[ipos]["tbl_name"] as? String
                        else {
                            var msg: String = "Error indexes tbl_name "
                            msg.append("not found")
                            throw ExportToJsonError
                            .createIndexes(message: msg)
                        }
                        if tblName == tableName {
                            guard let sql: String =
                                    resIndexes[ipos]["sql"] as? String
                            else {
                                var msg: String = "Error indexes sql "
                                msg.append("not found")
                                throw ExportToJsonError
                                .createIndexes(message: msg)
                            }
                            guard let name = resIndexes[ipos]["name"]
                                    as? String else {
                                var msg: String = "Error indexes name "
                                msg.append("not found")
                                throw ExportToJsonError
                                .createIndexes(message: msg)
                            }
                            guard let oPar = sql.lastIndex(of: "(")
                            else {
                                var msg: String = "Create Indexes no "
                                msg.append("'('")
                                throw ExportToJsonError
                                .createIndexes(message: msg)
                            }
                            guard let cPar = sql.lastIndex(of: ")")
                            else {
                                var msg: String = "Create Indexes no "
                                msg.append("')'")
                                throw ExportToJsonError
                                .createIndexes(message: msg)
                            }
                            if sql.contains("UNIQUE") {
                                row["mode"] = "UNIQUE"
                            }
                            row["value"] = String(sql[sql.index(
                                                        after: oPar)..<cPar])
                            row["name"] = name
                            retIndexes.append(row)
                        } else {
                            var msg: String = "Error indexes table name"
                            msg.append(" doesn't match")
                            throw ExportToJsonError
                            .createIndexes(message: msg)
                        }
                    } else {
                        throw ExportToJsonError.createIndexes(
                            message: "Error No indexes key found ")
                    }
                }
            }
        } catch UtilsSQLCipherError.querySQL(let message) {
            throw ExportToJsonError.createIndexes(
                message: "Error query indexes failed : \(message)")
        }

        return retIndexes
    }
    // swiftlint:enable cyclomatic_complexity
    // swiftlint:enable function_body_length

    // MARK: - ExportToJson - CreateTriggers

    // swiftlint:disable function_body_length
    // swiftlint:disable cyclomatic_complexity

    class func createTriggers(mDB: Database, tableName: String)
    throws -> [[String: String]] {
        var retTriggers: [[String: String]] = []
        var query = "SELECT name,tbl_name,sql FROM sqlite_master WHERE "
        query.append("type = 'trigger' AND tbl_name = '\(tableName)' ")
        query.append("AND sql NOTNULL;")
        do {
            var resTriggers =  try UtilsSQLCipher.querySQL(
                mDB: mDB, sql: query, values: [])
            if resTriggers.count > 1 {
                resTriggers.removeFirst()
                for ipos in 0..<resTriggers.count {
                    var row: [String: String] = [:]
                    let keys: [String] = Array(resTriggers[ipos].keys)
                    if keys.count == 3 {
                        guard let tblName =
                                resTriggers[ipos]["tbl_name"] as? String
                        else {
                            var msg: String = "Error triggers tbl_name "
                            msg.append("not found")
                            throw ExportToJsonError
                            .createTriggers(message: msg)
                        }
                        if tblName == tableName {
                            guard let sql: String =
                                    resTriggers[ipos]["sql"] as? String
                            else {
                                var msg: String = "Error triggers sql "
                                msg.append("not found")
                                throw ExportToJsonError
                                .createTriggers(message: msg)
                            }
                            guard let name = resTriggers[ipos]["name"]
                                    as? String else {
                                var msg: String = "Error triggers name "
                                msg.append("not found")
                                throw ExportToJsonError
                                .createTriggers(message: msg)
                            }
                            var sqlArr: [String] = sql.components(separatedBy: name)
                            if sqlArr.count != 2 {
                                var msg = "Error sql split name does not "
                                msg.append("return 2 values")
                                throw ExportToJsonError
                                .createTriggers(message: msg)
                            }
                            if !sqlArr[1].contains(tableName) {
                                var msg = "sql split does not contains "
                                msg.append("\(tableName)")
                                throw ExportToJsonError
                                .createTriggers(message: msg)
                            }
                            var timeevent: String = sqlArr[1]
                                .components(separatedBy: tableName)[0]
                                .trimmingCharacters(in:
                                                        .whitespacesAndNewlines)
                            var sep: String = "\(timeevent) \(tableName)"
                            sqlArr = sqlArr[1].components(separatedBy: sep)
                            if sqlArr.count != 2 {
                                var msg = "Error sql split tableName does not "
                                msg.append("return 2 values")
                                throw ExportToJsonError
                                .createTriggers(message: msg)
                            }
                            var condition: String = ""
                            var logic: String = ""
                            sep = sqlArr[1]
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                            if !sep.uppercased().hasPrefix("BEGIN") {
                                sqlArr = sep.components(separatedBy: "BEGIN")
                                if sqlArr.count != 2 {
                                    var msg = "Error sql split BEGIN does not "
                                    msg.append("return 2 values")
                                    throw ExportToJsonError
                                    .createTriggers(message: msg)
                                }
                                condition = sqlArr[0]
                                    .trimmingCharacters(in: .whitespacesAndNewlines)
                                logic = "BEGIN\(sqlArr[1])"
                            } else {
                                logic = sep
                            }
                            if timeevent.uppercased().hasSuffix(" ON") {
                                timeevent = String(timeevent.dropLast(3))
                            }

                            row["timeevent"] = timeevent
                            row["name"] = name
                            if condition.count > 0 {
                                row["condition"] = condition
                            }
                            row["logic"] = logic
                            retTriggers.append(row)
                        } else {
                            var msg: String = "Error triggers table name"
                            msg.append(" doesn't match")
                            throw ExportToJsonError
                            .createTriggers(message: msg)
                        }
                    } else {
                        throw ExportToJsonError.createTriggers(
                            message: "Error No triggers key found ")
                    }
                }
            }
        } catch UtilsSQLCipherError.querySQL(let message) {
            throw ExportToJsonError.createTriggers(
                message: "Error query triggers failed : \(message)")
        }

        return retTriggers
    }
    // swiftlint:enable cyclomatic_complexity
    // swiftlint:enable function_body_length

    // MARK: - ExportToJson - CreateValues

    class func createValues(mDB: Database,
                            query: String, names: [String],
                            types: [String]) throws -> [[Any]] {

        var retValues: [[Any]] = []
        do {
            var resValues =  try UtilsSQLCipher.querySQL(
                mDB: mDB, sql: query, values: [])
            if resValues.count > 1 {
                resValues.removeFirst()
                for ipos in 0..<resValues.count {
                    var row: [Any] = []
                    do {
                        row = try ExportToJson.createRowValues(
                            values: resValues, pos: ipos, names: names,
                            types: types)
                    } catch ExportToJsonError
                                .createRowValues(let message) {
                        var msg: String = "Error create row values "
                        msg.append("failed : \(message)")
                        throw ExportToJsonError.createValues(
                            message: msg)
                    }
                    retValues.append(row)
                }
            }
        } catch UtilsSQLCipherError.querySQL(let message) {
            throw ExportToJsonError.createValues(
                message: "Error query values failed : \(message)")
        }

        return retValues
    }

    // MARK: - ExportToJson - CreateRowValues

    // swiftlint:disable function_body_length
    // swiftlint:disable cyclomatic_complexity
    class func createRowValues(values: [[String: Any]], pos: Int,
                               names: [String],
                               types: [String] ) throws -> [Any] {
        var row: [Any] = []
        for jpos in 0..<names.count {
            if values[pos][names[jpos]] is String  && (TEXTAFFINITY
                                                        .contains(types[jpos].components(separatedBy: "(")[0]
                                                                    .uppercased())
                                                        || BLOBAFFINITY.contains(types[jpos].uppercased())
                                                        || NUMERICAFFINITY.contains(types[jpos].uppercased())
            ) {
                guard let val = values[pos][names[jpos]] as? String
                else {
                    throw ExportToJsonError.createValues(
                        message: "Error value must be String")
                }
                row.append(val)
            } else if values[pos][names[jpos]] is NSNull {
                guard let val = values[pos][names[jpos]] as? NSNull
                else {
                    throw ExportToJsonError.createValues(
                        message: "Error value must be NSNull")
                }
                row.append(val)
            } else if values[pos][names[jpos]] is Int64 && (
                        INTEGERAFFINITY.contains(types[jpos].uppercased()) ||
                            INTEGERAFFINITY.contains(types[jpos]
                                                        .components(separatedBy: "(")[0].uppercased()) ||
                            NUMERICAFFINITY.contains(types[jpos].uppercased())) {
                guard let val = values[pos][names[jpos]] as? Int64
                else {
                    throw ExportToJsonError.createValues(
                        message: "Error value must be Int64")
                }
                row.append(val)
            } else if values[pos][names[jpos]] is Int64 && (
                        REALAFFINITY.contains(types[jpos].uppercased())  ||
                            NUMERICAFFINITY.contains(types[jpos]
                                                        .components(separatedBy: "(")[0].uppercased())) {
                guard let val = values[pos][names[jpos]] as? Int64
                else {
                    throw ExportToJsonError.createValues(
                        message: "Error value must be double")
                }
                row.append(Double(val))
            } else if values[pos][names[jpos]] is Double && (
                        REALAFFINITY.contains(types[jpos].uppercased()) ||
                            NUMERICAFFINITY.contains(types[jpos]
                                                        .components(separatedBy: "(")[0].uppercased())) {
                guard let val = values[pos][names[jpos]] as? Double
                else {
                    throw ExportToJsonError.createValues(
                        message: "Error value must be double")
                }
                row.append(val)
            } else if values[pos][names[jpos]] is [UInt8] &&
                        BLOBAFFINITY.contains(types[jpos].uppercased()) {
                guard let val = values[pos][names[jpos]] as? [UInt8]
                else {
                    throw ExportToJsonError.createValues(
                        message: "Error value must be [UInt8]")
                }
                row.append(val)

            } else {
                throw ExportToJsonError.createValues(
                    message: "Error value is not (string, nsnull," +
                        "int64,double,[UInt8]) ")
            }
        }
        return row
    }
    // swiftlint:enable cyclomatic_complexity
    // swiftlint:enable function_body_length

}
// swiftlint:enable type_body_length
// swiftlint:enable file_length
