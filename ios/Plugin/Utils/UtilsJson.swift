//
//  UtilsJson.swift
//  CapacitorCommunitySqlite
//
//  Created by  Quéau Jean Pierre on 30/07/2020.
//

import Foundation
enum UtilsJsonError: Error {
    case tableNotExists(message: String)
    case getTableColumnNamesTypes(message: String)
    case validateSchema(message: String)
    case validateIndexes(message: String)
    case validateTriggers(message: String)
}

class UtilsJson {

    // MARK: - ImportFromJson - IsTableExists

    class func isTableExists(mDB: Database, tableName: String)
    throws -> Bool {
        var msg: String = "Error isTableExists: "
        if !mDB.isDBOpen() {
            msg.append("Database not opened")
            throw UtilsJsonError.tableNotExists(message: msg)
        }
        var ret: Bool = false
        var query = "SELECT name FROM sqlite_master WHERE type='table'"
        query.append(" AND name='")
        query.append(tableName)
        query.append("';")
        do {
            var resQuery: [Any] = try UtilsSQLCipher
                .querySQL(mDB: mDB, sql: query, values: [])
            if resQuery.count > 0 {
                resQuery.removeFirst()
                if resQuery.count == 1 {
                    ret = true
                }
            }
        } catch UtilsSQLCipherError.querySQL(let message) {
            throw UtilsJsonError.tableNotExists(message: message)
        }
        return ret
    }

    // MARK: - ImportFromJson - GetTableColumnNamesTypes

    class func getTableColumnNamesTypes(mDB: Database,
                                        tableName: String)
    throws -> JsonNamesTypes {
        var ret: JsonNamesTypes = JsonNamesTypes(names: [], types: [])
        var msg: String = "Error: getTableColumnNamesTypes "
        var query: String = "PRAGMA table_info('"
        query.append(tableName)
        query.append("');")
        do {
            var resQuery =  try mDB.selectSQL(sql: query, values: [])
            if resQuery.count > 0 {
                resQuery.removeFirst()
                var names: [String] = []
                var types: [String] = []
                for ipos in 0..<resQuery.count {
                    if let mName = resQuery[ipos]["name"] as? String {
                        names.append("\(mName)")
                    } else {
                        msg.append("no name")
                        throw UtilsJsonError.getTableColumnNamesTypes(
                            message: msg)
                    }
                    if let mType = resQuery[ipos]["type"] as? String {
                        types.append("\(mType)")
                    } else {
                        msg.append("no type")
                        throw UtilsJsonError.getTableColumnNamesTypes(
                            message: msg)
                    }
                }
                ret.names.append(contentsOf: names)
                ret.types.append(contentsOf: types)
            }
        } catch DatabaseError.selectSQL(let message) {
            msg.append("\(message)")
            throw UtilsJsonError.getTableColumnNamesTypes(message: msg)
        }
        return ret
    }

    // MARK: - ImportFromJson - CreateQuestionMarkString

    class func createQuestionMarkString(length: Int) -> String {
        var retString: String = ""
        for _ in 0..<length {
            retString += "?,"
        }
        retString = String(retString.dropLast())
        return retString
    }

    // MARK: - ImportFromJson - GetValuesFromRow

    class func getValuesFromRow(
        rowValues: [ UncertainValue<String, Int, Double, [UInt8]>]) -> [Any] {
        var retArray: [Any] = []
        for ipos in 0..<rowValues.count {
            let value = rowValues[ipos].value
            retArray.append(value ?? NSNull())
        }
        return retArray
    }

    // MARK: - ExportToJson - validateSchema

    class func validateSchema(schema: [[String: String]])
    throws -> Bool {
        var isSchema = false
        do {
            let eSchema = try JSONEncoder().encode(schema)
            guard let eSchemaString: String = String(
                    data: eSchema, encoding: .utf8) else {
                var message: String = "Error in converting eSchema "
                message.append("to String")
                throw UtilsJsonError.validateSchema(
                    message: message)
            }
            if eSchemaString.count > 0 {
                isSchema = true
            }
        } catch {
            throw UtilsJsonError.validateSchema(
                message: "Error in encoding schema")
        }
        return isSchema
    }

    // MARK: - ExportToJson - validateIndexes

    class func validateIndexes(indexes: [[String: String]])
    throws -> Bool {

        var isIndexes = false
        do {
            let eIndexes = try JSONEncoder().encode(indexes)
            guard let eIndexesString: String =
                    String(data: eIndexes, encoding: .utf8) else {
                var message: String = "Error in converting "
                message.append("eIndexes to String")
                throw UtilsJsonError.validateIndexes(
                    message: message)
            }
            if eIndexesString.count > 0 {
                isIndexes = true
            }
        } catch {
            throw UtilsJsonError.validateIndexes(
                message: "Error in encoding indexes")
        }
        return isIndexes
    }

    // MARK: - ExportToJson - validateTriggers

    class func validateTriggers(triggers: [[String: String]])
    throws -> Bool {

        var isTriggers = false
        do {
            let eTriggers = try JSONEncoder().encode(triggers)
            guard let eTriggersString: String =
                    String(data: eTriggers, encoding: .utf8) else {
                var message: String = "Error in converting "
                message.append("eTriggers to String")
                throw UtilsJsonError.validateTriggers(
                    message: message)
            }
            if eTriggersString.count > 0 {
                isTriggers = true
            }
        } catch {
            throw UtilsJsonError.validateTriggers(
                message: "Error in encoding triggers")
        }
        return isTriggers
    }

}
