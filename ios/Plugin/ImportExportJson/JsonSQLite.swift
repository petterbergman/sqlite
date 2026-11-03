//
//  JsonSQLite.swift
//  Plugin
//
//  Created by  Quéau Jean Pierre on 18/01/2021.
//  Copyright © 2021 Max Lynch. All rights reserved.
//

import Foundation

public struct JsonSQLite: Codable {
    let database: String
    let version: Int
    var overwrite: Bool?
    // Only "full" is supported; the key is accepted for compatibility with jeep-sqlite
    var mode: String?
    let tables: [JsonTable]
    var views: [JsonView]?
}

public struct JsonTable: Codable {
    let name: String
    var schema: [JsonColumn]?
    var indexes: [JsonIndex]?
    var triggers: [JsonTrigger]?
    var values: [[UncertainValue<String, Int, Double, [UInt8]>]]?
}

public struct JsonColumn: Codable {
    var column: String?
    let value: String
    var foreignkey: String?
    var constraint: String?
}

public struct JsonIndex: Codable {
    let name: String
    let value: String
    let mode: String?
}
public struct JsonTrigger: Codable {
    var name: String
    let timeevent: String
    var condition: String?
    let logic: String
}
public struct UncertainValue<T: Codable, U: Codable, V: Codable, W: Codable>: Codable {
    public var tValue: T?
    public var uValue: U?
    public var vValue: V?
    public var wValue: W?
    public var value: Any? {
        return tValue ?? uValue ?? vValue ?? wValue
    }
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        tValue = try? container.decode(T.self)
        uValue = try? container.decode(U.self)
        if uValue == nil {
            vValue = try? container.decode(V.self)
        }
        if vValue == nil {
            wValue = try? container.decode(W.self)
        }
    }
}
public struct JsonView: Codable {
    let name: String
    let value: String
}

public struct JsonNamesTypes {
    var names: [String]
    var types: [String]
}
