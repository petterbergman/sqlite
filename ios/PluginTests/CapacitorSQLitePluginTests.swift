import XCTest
@testable import Plugin

class CapacitorSQLiteTests: XCTestCase {

    func testEcho() {
        // This is an example of a functional test case for a plugin.
        // Use XCTAssert and related functions to verify your tests produce the correct results.

        let implementation = CapacitorSQLite(config: SqliteConfig())
        let value = "Hello, World!"
        let result = implementation.echo(value)

        XCTAssertEqual(value, result)
    }

    func testImportFromJsonBasic() {
        let implementation = CapacitorSQLite(config: SqliteConfig())
        // Load JSON from file next to this test source
        let thisDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
        let jsonURL = thisDir.appendingPathComponent("basic.json")
        let json: String
        do {
            json = try String(contentsOf: jsonURL, encoding: .utf8)
        } catch {
            XCTFail("Failed to read basic.json: \(error)")
            return
        }
        // Extract db name from JSON file for later assertions
        let dbName = "testjson_file"

        do {
            try implementation.isJsonValid(json)
        } catch {
            XCTFail("isJsonValid failed: \(error)")
            return
        }
        let res: [String: Int]
        do {
            res = try implementation.importFromJson(json)
        } catch {
            XCTFail("importFromJson failed: \(error)")
            return
        }
        XCTAssertGreaterThanOrEqual(res["changes"] ?? -1, 0, "importFromJson reported negative changes")

        do {
            try implementation.createConnection(dbName,
                                                encrypted: false,
                                                mode: "no-encryption",
                                                version: 1,
                                                vUpgDict: [:],
                                                readonly: false)
        } catch {
            XCTFail("createConnection failed: \(error)")
            return
        }
        do {
            try implementation.open(dbName, readonly: false)
        } catch {
            XCTFail("open failed: \(error)")
            return
        }
        let rows: [[String: Any]]
        do {
            rows = try implementation.query(dbName,
                                            statement: "SELECT COUNT(*) AS cnt FROM users",
                                            values: [],
                                            readonly: false)
        } catch {
            XCTFail("query failed: \(error)")
            return
        }
        XCTAssertTrue(rows.count > 1)
        if let cnt = rows[1]["cnt"] as? Int64 {
            XCTAssertEqual(cnt, 2)
        } else if let cnt = rows[1]["cnt"] as? Int {
            XCTAssertEqual(cnt, 2)
        } else {
            XCTFail("Count column not found or wrong type")
        }

        do { try implementation.close(dbName, readonly: false) } catch { XCTFail("close failed: \(error)") }
        do { try implementation.deleteDatabase(dbName, readonly: false) } catch { XCTFail("deleteDatabase failed: \(error)") }
        do { try implementation.closeConnection(dbName, readonly: false) } catch { XCTFail("closeConnection failed: \(error)") }
    }

    func testQueryAllTablesWithTiming() {

        let implementation = CapacitorSQLite(config: SqliteConfig())
        // Copy DB from the test bundle into the databases folder using UtilsFile helper
        do {
            // Locate DB in the test bundle (either at root or under public/assets/databases)
            let bundle = Bundle(for: type(of: self))
            var sourceFileURL: URL?
            if let url = bundle.url(forResource: "Quartermaster4SQLite", withExtension: "db") {
                sourceFileURL = url
            } else if let baseURL = bundle.resourceURL?.appendingPathComponent("public/assets/databases"),
                      FileManager.default.fileExists(atPath: baseURL.appendingPathComponent("Quartermaster4SQLite.db").path) {
                sourceFileURL = baseURL.appendingPathComponent("Quartermaster4SQLite.db")
            }
            guard let fileURL = sourceFileURL else {
                XCTFail("Quartermaster4SQLite.db not found in test bundle")
                return
            }
            let sourceDirURL = fileURL.deletingLastPathComponent()
            let destDirURL = try UtilsFile.getFolderURL(folderPath: "Documents")
            try UtilsFile.copyFromNames(dbPathURL: sourceDirURL,
                                        fromFile: "Quartermaster4SQLite.db",
                                        databaseURL: destDirURL,
                                        toFile: "Quartermaster4SQLite.db")
        } catch {
            XCTFail("copyFromNames failed: \(error)")
            return
        }

        let dbName = "Quartermaster4"
        do {
            try implementation.createConnection(dbName,
                                                encrypted: false,
                                                mode: "no-encryption",
                                                version: 1,
                                                vUpgDict: [:],
                                                readonly: false)
            try implementation.open(dbName, readonly: false)
        } catch {
            XCTFail("open Quartermaster4 failed: \(error)")
            return
        }

        let totalStart = Date()
        do {
            let tListStart = Date()
            let tables = try implementation.getTableList(dbName, readonly: false)
            let tListMs = Int(Date().timeIntervalSince(tListStart) * 1000)
            print("[TEST] (existing) getTableList() took \(tListMs)ms, count=\(tables.count)")
            for table in tables {
                let tCountStart = Date()
                let countRows = try implementation.query(dbName,
                                                         statement: "SELECT COUNT(*) AS cnt FROM \(table)",
                                                         values: [],
                                                         readonly: false)
                let tCountMs = Int(Date().timeIntervalSince(tCountStart) * 1000)
                var cntVal: Int = -1
                if countRows.count > 1 {
                    if let c = countRows[1]["cnt"] as? Int { cntVal = c }
                    else if let c64 = countRows[1]["cnt"] as? Int64 { cntVal = Int(c64) }
                }
                print("[TEST] (existing) table=\(table) count=\(cntVal) (\(tCountMs)ms)")

                let tSelStart = Date()
                let allRows = try implementation.query(dbName,
                                                       statement: "SELECT * FROM \(table)",
                                                       values: [],
                                                       readonly: false)
                let tSelMs = Int(Date().timeIntervalSince(tSelStart) * 1000)
                print("[TEST] (existing) table=\(table) full select rows=\(allRows.count - 1) (\(tSelMs)ms)")
            }
        } catch {
            XCTFail("query timing existing DB failed: \(error)")
        }
        do { try implementation.close(dbName, readonly: false) } catch { XCTFail("close failed: \(error)") }
        do { try implementation.closeConnection(dbName, readonly: false) } catch { XCTFail("closeConnection failed: \(error)") }
        let totalMs = Int(Date().timeIntervalSince(totalStart) * 1000)
        print("[TEST] testQueryAllTablesExistingDBTiming total elapsed \(totalMs)ms")
    }
}
