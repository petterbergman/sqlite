//
//  ImportFromJson.swift
//  Plugin
//
//  Created by  Quéau Jean Pierre on 18/01/2021.
//  Copyright © 2021 Max Lynch. All rights reserved.
//

import Foundation
import SQLite3

enum ImportFromJsonError: Error {
    case createDatabaseSchema(message: String)
    case createDatabaseData(message: String)
    case createSchema(message: String)
    case createTableData(message: String)
    case createView(message: String)
    case createViews(message: String)
}
class ImportFromJson {

    // MARK: - ImportFromJson - CreateDatabaseSchema

    class func createDatabaseSchema(mDB: Database, tables: [JsonTable],
                                    version: Int)
    throws -> Int {
        let msg = "importFromJson: "

        do {
            // Set PRAGMAS
            try UtilsSQLCipher.setVersion(mDB: mDB,
                                          version: version)
            // Drop All Tables, Indexes and Triggers
            try _ = UtilsDrop.dropAll(mDB: mDB)
            // create database schema
            return try ImportFromJson.createSchema(mDB: mDB, tables: tables)

        } catch UtilsSQLCipherError.setVersion(let message) {
            throw ImportFromJsonError.createDatabaseSchema(
                message: "\(msg) \(message)")
        } catch UtilsDropError.dropAllFailed(let message) {
            throw ImportFromJsonError.createDatabaseSchema(
                message: "\(msg) \(message)")
        } catch ImportFromJsonError.createSchema(let message) {
            throw ImportFromJsonError.createDatabaseSchema(
                message: "\(msg) \(message)")
        }
    }

    // MARK: - ImportFromJson - createSchema

    // swiftlint:disable function_body_length
    class func createSchema(mDB: Database, tables: [JsonTable]) throws -> Int {
        var changes: Int = 0
        var initChanges: Int = 0
        // Create a Schema Statements
        let statements = ImportFromJson.createSchemaStatement(tables: tables)
        if statements.count == 0 {
            return changes
        }
        do {
            // Start a transaction
            try UtilsSQLCipher.beginTransaction(mDB: mDB)
        } catch UtilsSQLCipherError.beginTransaction(let message) {
            throw ImportFromJsonError.createSchema(message: message)
        }
        let joined = statements.joined(separator: "\n")
        let mStmt: String = joined.replacingOccurrences(of: "\'", with: "'")

        do {
            initChanges = UtilsSQLCipher.dbChanges(mDB: mDB.mDb)
            // Execute Schema Statements
            try UtilsSQLCipher.execute(mDB: mDB, sql: mStmt)
            changes = UtilsSQLCipher.dbChanges(mDB: mDB.mDb) -
                initChanges
            if changes < 0 {
                do {
                    // Rollback the transaction
                    try UtilsSQLCipher
                        .rollbackTransaction(mDB: mDB)
                } catch UtilsSQLCipherError
                            .rollbackTransaction(let message) {
                    throw ImportFromJsonError
                    .createSchema(message: message)
                }
            }
            // Commit the transaction
            try UtilsSQLCipher.commitTransaction(mDB: mDB)

        } catch UtilsSQLCipherError.execute(let message) {
            var msg = message
            do {
                // Rollback the transaction
                try UtilsSQLCipher
                    .rollbackTransaction(mDB: mDB)
                throw ImportFromJsonError
                .createSchema(message: message)
            } catch UtilsSQLCipherError
                        .rollbackTransaction(let message) {
                msg.append(" rollback: \(message)")
                throw ImportFromJsonError
                .createSchema(message: msg)
            }
        } catch UtilsSQLCipherError.commitTransaction(let message) {
            throw ImportFromJsonError
            .createSchema(message: message)
        }
        return changes
    }
    // swiftlint:enable function_body_length

    // MARK: - ImportFromJson - createSchemaStatement

    class func createSchemaStatement(tables: [JsonTable]) -> [String] {
        // Create the Database Schema
        var statements: [String] = []
        // Loop through Tables
        for table in tables {
            if let mSchema = table.schema, mSchema.count > 0 {
                statements.append(ImportFromJson.createTableSchema(
                                    mSchema: mSchema, tableName: table.name))
            }
            if let mIndexes = table.indexes, mIndexes.count > 0 {
                statements.append(contentsOf: ImportFromJson.createTableIndexes(
                                    mIndexes: mIndexes, tableName: table.name))
            }
            if let mTriggers = table.triggers, mTriggers.count > 0 {
                statements.append(contentsOf: ImportFromJson.createTableTriggers(
                                    mTriggers: mTriggers, tableName: table.name))
            }
        }
        return statements
    }

    // MARK: - ImportFromJson - CreateTableSchema

    class func createTableSchema(mSchema: [JsonColumn],
                                 tableName: String) -> String {
        var stmt: String = "CREATE TABLE IF NOT EXISTS "
        stmt.append(tableName)
        stmt.append(" (")
        for jpos in 0..<mSchema.count {
            if let jSchColumn = mSchema[jpos].column, jSchColumn.count > 0 {
                stmt.append(jSchColumn)
            }
            if let jSchForeignkey = mSchema[jpos].foreignkey, jSchForeignkey.count > 0 {
                stmt.append("FOREIGN KEY (\( jSchForeignkey))")
            }
            if let jSchConstraint = mSchema[jpos].constraint, jSchConstraint.count > 0 {
                stmt.append("CONSTRAINT \( jSchConstraint)")
            }
            stmt.append(" ")
            stmt.append(mSchema[jpos].value)
            if jpos != mSchema.count - 1 {
                stmt.append(",")
            }
        }
        stmt.append(");")
        return stmt
    }

    // MARK: - ImportFromJson - CreateTableIndexes

    class func createTableIndexes(mIndexes: [JsonIndex],
                                  tableName: String) -> [String] {
        var statements: [String] = []
        for jpos in 0..<mIndexes.count {
            var mUnique: String = ""
            if var mMode = mIndexes[jpos].mode {
                mMode = mMode.uppercased()
                if mMode == "UNIQUE" {
                    mUnique = mMode + " "
                }
            }
            var stmt: String
            stmt = "CREATE "
            stmt.append(mUnique)
            stmt.append("INDEX IF NOT EXISTS ")
            stmt.append(mIndexes[jpos].name)
            stmt.append(" ON ")
            stmt.append(tableName)
            stmt.append(" (")
            stmt.append(mIndexes[jpos].value)
            stmt.append(");")
            statements.append(stmt)
        }
        return statements
    }

    // MARK: - ImportFromJson - CreateTableTriggers

    class func createTableTriggers(mTriggers: [JsonTrigger],
                                   tableName: String) -> [String] {
        var statements: [String] = []

        for jpos in 0..<mTriggers.count {
            var timeevent: String = mTriggers[jpos].timeevent
            if timeevent.uppercased().hasSuffix(" ON") {
                timeevent = String(timeevent.dropLast(3))
            }
            var stmt: String
            stmt = "CREATE TRIGGER IF NOT EXISTS "
            stmt.append(mTriggers[jpos].name)
            stmt.append(" ")
            stmt.append(timeevent)
            stmt.append(" ON ")
            stmt.append("\(tableName) ")
            if let condition = mTriggers[jpos].condition {
                stmt.append("\(condition) ")
            }
            stmt.append("\(mTriggers[jpos].logic);")
            statements.append(stmt)
        }
        return statements
    }

    // MARK: - ImportFromJson - createDatabaseData

    // swiftlint:disable function_body_length
    class func createDatabaseData(mDB: Database,
                                  tables: [JsonTable]) throws -> Int {
        var initChanges: Int = -1

        do {
            initChanges = UtilsSQLCipher.dbChanges(mDB: mDB.mDb)
            // Start a transaction
            try UtilsSQLCipher.beginTransaction(mDB: mDB)
        } catch UtilsSQLCipherError.beginTransaction(let message) {
            throw ImportFromJsonError.createDatabaseData(message: message)
        }
        // Loop on tables to create Data
        for table in tables {
            guard let mValues = table.values, mValues.count > 0 else {
                continue
            }
            do {
                try ImportFromJson.createTableData(
                    mDB: mDB,
                    mValues: mValues.map { UtilsJson.getValuesFromRow(rowValues: $0) },
                    tableName: table.name)
            } catch ImportFromJsonError
                        .createTableData(let message) {
                // Rollback Transaction
                var msg = message
                do {
                    // Rollback the transaction
                    try UtilsSQLCipher
                        .rollbackTransaction(mDB: mDB)
                    throw ImportFromJsonError
                    .createDatabaseData(message: message)
                } catch UtilsSQLCipherError
                            .rollbackTransaction(let message) {
                    msg.append(" rollback: \(message)")
                    throw ImportFromJsonError
                    .createDatabaseData(message: msg)
                }
            }
        }
        do {
            // Commit the transaction
            try UtilsSQLCipher.commitTransaction(mDB: mDB)
            return UtilsSQLCipher.dbChanges(mDB: mDB.mDb) - initChanges
        } catch UtilsSQLCipherError.commitTransaction(
                    let message) {
            throw ImportFromJsonError.createDatabaseData(
                message: message)
        }
    }
    // swiftlint:enable function_body_length

    // MARK: - ImportFromJson - createTableData

    class func createTableData(
        mDB: Database,
        mValues: [[Any]],
        tableName: String) throws {
        // Check if table exists
        do {
            let isTab: Bool = try UtilsJson
                .isTableExists(mDB: mDB, tableName: tableName)
            if !isTab {
                let message: String = "createTableData: Table " +
                    tableName + " does not exist"
                throw ImportFromJsonError.createTableData(
                    message: message)
            }
        } catch UtilsJsonError.tableNotExists(let message) {
            throw ImportFromJsonError.createTableData(message: message)
        }
        // Get the Column's Name and Type
        var jsonNamesTypes: JsonNamesTypes =
            JsonNamesTypes(names: [], types: [])
        do {
            jsonNamesTypes = try UtilsJson
                .getTableColumnNamesTypes(mDB: mDB,
                                          tableName: tableName)
        } catch UtilsJsonError.getTableColumnNamesTypes(let message) {
            throw ImportFromJsonError.createTableData(message: message)
        }
        let nameString: String = jsonNamesTypes.names.joined(separator: ",")
        let questionMarkString: String = UtilsJson.createQuestionMarkString(
            length: jsonNamesTypes.names.count)
        let stmt = "INSERT INTO \(tableName) (\(nameString)) VALUES (\(questionMarkString));"
        for rowValues in mValues {
            do {
                let resp = try UtilsSQLCipher.prepareSQL(
                    mDB: mDB, sql: stmt, values: rowValues)
                if resp.0 < 0 {
                    throw ImportFromJsonError.createTableData(
                        message: "lastId < 0")
                }
            } catch UtilsSQLCipherError.prepareSQL(let message) {
                throw ImportFromJsonError.createTableData(message: message)
            }
        }
    }

    // MARK: - ImportFromJson - createViews

    // swiftlint:disable function_body_length
    class func createViews(mDB: Database, views: [JsonView]) throws -> Int {
        var changes: Int = 0
        var initChanges: Int = -1
        var isView: Bool = false
        var msg: String = ""

        do {
            initChanges = UtilsSQLCipher.dbChanges(mDB: mDB.mDb)
            // Start a transaction
            try UtilsSQLCipher.beginTransaction(mDB: mDB)
        } catch UtilsSQLCipherError.beginTransaction(let message) {
            throw ImportFromJsonError.createDatabaseData(message: message)
        }
        for view in views {
            if view.name.count > 0 && view.value.count > 0 {
                do {
                    try ImportFromJson.createView(
                        mDB: mDB,
                        view: view)
                    isView = true
                } catch ImportFromJsonError
                            .createView(let message) {
                    msg = message
                }
            } else {
                msg = "no name and value"
                break
            }
        }
        if isView {
            // commit
            do {
                // Commit the transaction
                try UtilsSQLCipher.commitTransaction(mDB: mDB)
                changes = UtilsSQLCipher
                    .dbChanges(mDB: mDB.mDb) - initChanges
            } catch UtilsSQLCipherError.commitTransaction(
                        let message) {
                throw ImportFromJsonError.createDatabaseData(
                    message: message)
            }
        } else {
            if msg.count > 0 {
                // rollback
                do {
                    // Rollback the transaction
                    try UtilsSQLCipher
                        .rollbackTransaction(mDB: mDB)
                    throw ImportFromJsonError
                    .createViews(message: msg)
                } catch UtilsSQLCipherError
                            .rollbackTransaction(let message) {
                    msg.append(" rollback: \(message)")
                    throw ImportFromJsonError
                    .createViews(message: msg)
                }
            } else {
                changes = 0
            }
        }
        return changes

    }
    // swiftlint:enable function_body_length
    class func createView(mDB: Database, view: JsonView) throws {
        let stmt = "CREATE VIEW IF NOT EXISTS \(view.name) AS \(view.value);"
        do {
            try UtilsSQLCipher.execute(mDB: mDB, sql: stmt)
        } catch UtilsSQLCipherError.execute(let message) {
            throw ImportFromJsonError
            .createView(message: message)
        }
    }
}
