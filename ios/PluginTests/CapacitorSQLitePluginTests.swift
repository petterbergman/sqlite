import XCTest
@testable import CapacitorSQLitePlugin

class CapacitorSQLiteTests: XCTestCase {

    override func setUpWithError() throws {
        // Hostless tests use the simulator's home dir, which lacks Documents on a fresh simulator
        let docs = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask,
                                               appropriateFor: nil, create: true)
        try FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
    }

    private func loadBasicJson() throws -> String {
        // Load JSON from file next to this test source
        let thisDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
        return try String(contentsOf: thisDir.appendingPathComponent("basic.json"), encoding: .utf8)
    }

    private func countRows(_ rows: [[String: Any]]) -> Int64? {
        // iOS returns the column names as the first row
        guard rows.count > 1 else { return nil }
        if let cnt = rows[1]["cnt"] as? Int64 { return cnt }
        if let cnt = rows[1]["cnt"] as? Int { return Int64(cnt) }
        return nil
    }

    func testImportFromJsonBasic() throws {
        let implementation = CapacitorSQLite(config: SqliteConfig())
        let json = try loadBasicJson()
        let dbName = "testjson_file"

        try implementation.isJsonValid(json)
        let res = try implementation.importFromJson(json)
        XCTAssertGreaterThanOrEqual(res["changes"] ?? -1, 0, "importFromJson reported negative changes")

        try implementation.createConnection(dbName, version: 1)
        try implementation.open(dbName)
        let rows = try implementation.query(dbName,
                                            statement: "SELECT COUNT(*) AS cnt FROM users",
                                            values: [])
        XCTAssertEqual(countRows(rows), 2)

        let export = try implementation.exportToJson(dbName)
        XCTAssertEqual(export["database"] as? Substring, "testjson_file")
        let tables = export["tables"] as? [[String: Any]]
        XCTAssertEqual(tables?.first?["name"] as? String, "users")
        XCTAssertEqual((tables?.first?["values"] as? [[Any]])?.count, 2)

        try implementation.close(dbName)
        try implementation.closeConnection(dbName)
        XCTAssertEqual(try implementation.isDatabase(dbName), 1)
        let dbPath = try UtilsFile.getFilePath(databaseLocation: "Documents",
                                               fileName: "\(dbName)SQLite.db")
        try FileManager.default.removeItem(atPath: dbPath)
    }

    func testRejectsPartialJson() throws {
        let implementation = CapacitorSQLite(config: SqliteConfig())
        let json = try loadBasicJson().replacingOccurrences(of: "\"full\"", with: "\"partial\"")
        XCTAssertThrowsError(try implementation.isJsonValid(json))
        XCTAssertThrowsError(try implementation.importFromJson(json))
    }

    func testCreateSchemaSplitsOnAnyWhitespace() throws {
        // Column definitions separated by tabs or CRLF used to fail the schema export
        let stmt = "CREATE TABLE tabbed (id\tINTEGER PRIMARY KEY NOT NULL,\r\n  name\t\tTEXT,"
            + "\r\n  CONSTRAINT\tuq_name UNIQUE (name))"
        let schema = try ExportToJson.createSchema(stmt: stmt)
        XCTAssertEqual(schema.count, 3)
        XCTAssertEqual(schema[0]["column"], "id")
        XCTAssertEqual(schema[0]["value"], "INTEGER PRIMARY KEY NOT NULL")
        XCTAssertEqual(schema[1]["column"], "name")
        XCTAssertEqual(schema[1]["value"], "TEXT")
        XCTAssertEqual(schema[2]["constraint"], "uq_name")
        XCTAssertEqual(schema[2]["value"], "UNIQUE (name)")
    }

    func testQueryAllTablesWithTiming() throws {

        let implementation = CapacitorSQLite(config: SqliteConfig())
        // Copy DB from the test bundle into the databases folder
        let bundle = Bundle(for: type(of: self))
        var sourceFileURL: URL? = bundle.url(forResource: "Quartermaster4SQLite", withExtension: "db")
        if sourceFileURL == nil,
           let baseURL = bundle.resourceURL?.appendingPathComponent("public/assets/databases"),
           FileManager.default.fileExists(atPath: baseURL.appendingPathComponent("Quartermaster4SQLite.db").path) {
            sourceFileURL = baseURL.appendingPathComponent("Quartermaster4SQLite.db")
        }
        guard let fileURL = sourceFileURL else {
            throw XCTSkip("Quartermaster4SQLite.db not found in test bundle")
        }
        let destPath = try UtilsFile.getFilePath(databaseLocation: "Documents",
                                                 fileName: "Quartermaster4SQLite.db")
        if FileManager.default.fileExists(atPath: destPath) {
            try FileManager.default.removeItem(atPath: destPath)
        }
        try FileManager.default.copyItem(atPath: fileURL.path, toPath: destPath)

        let dbName = "Quartermaster4"
        try implementation.createConnection(dbName, version: 1)
        try implementation.open(dbName)

        let totalStart = Date()
        let tableRows = try implementation.query(
            dbName,
            statement: "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
            values: [])
        let tables = tableRows.dropFirst().compactMap { $0["name"] as? String }
        print("[TEST] (existing) table count=\(tables.count)")
        XCTAssertGreaterThan(tables.count, 0)
        for table in tables {
            let tCountStart = Date()
            let countRows = try implementation.query(dbName,
                                                     statement: "SELECT COUNT(*) AS cnt FROM \(table)",
                                                     values: [])
            let tCountMs = Int(Date().timeIntervalSince(tCountStart) * 1000)
            print("[TEST] (existing) table=\(table) count=\(countRows.count > 1 ? (self.countRows(countRows) ?? -1) : -1) (\(tCountMs)ms)")

            let tSelStart = Date()
            let allRows = try implementation.query(dbName,
                                                   statement: "SELECT * FROM \(table)",
                                                   values: [])
            let tSelMs = Int(Date().timeIntervalSince(tSelStart) * 1000)
            print("[TEST] (existing) table=\(table) full select rows=\(allRows.count - 1) (\(tSelMs)ms)")
        }
        try implementation.close(dbName)
        try implementation.closeConnection(dbName)
        let totalMs = Int(Date().timeIntervalSince(totalStart) * 1000)
        print("[TEST] testQueryAllTablesExistingDBTiming total elapsed \(totalMs)ms")
    }
}
