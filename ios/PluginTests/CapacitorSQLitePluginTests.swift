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
}
