//
//  UtilsFile.swift
//  Plugin
//
//  Created by  Quéau Jean Pierre on 18/01/2021.
//  Copyright © 2021 Max Lynch. All rights reserved.
//

import Foundation

enum UtilsFileError: Error {
    case getFilePathFailed
    case moveFileFailed
    case deleteFileFailed
    case getDatabasesURLFailed
    case getApplicationURLFailed
    case getCacheURLFailed
    case getLibraryURLFailed
    case getFileListFailed
    case getFolderURLFailed(message: String)
    case moveAllDBSQLiteFailed(message: String)
    case createDatabaseLocationFailed(message: String)
}
// swiftlint:disable file_length
// swiftlint:disable type_body_length
class UtilsFile {

    class func createDatabaseLocation(location: String) throws {
        do {
            var dirUrl: URL = try UtilsFile
                .getFolderURL(folderPath: location)
            let dirPath: String = dirUrl.path
            if !UtilsFile.isDirExist(dirPath: dirPath) {
                // create the directory
                try FileManager.default
                    .createDirectory(at: dirUrl, withIntermediateDirectories: true)
                // exclude the directory from iCloud Backup
                try UtilsFile.setExcludeFromiCloudBackup(&dirUrl,
                                                         isExcluded: true)
                // move all existing dbs from "Documents" to location folder
                if location.prefix(9) != "Documents" &&
                    location.prefix(7) != "default" {
                    let databaseURL: URL = try UtilsFile
                        .getDatabasesUrl().absoluteURL

                    try UtilsFile.moveAllDBSQLite(fromURL: databaseURL,
                                                  dirUrl: dirUrl)
                }
            }
        } catch UtilsFileError.getFolderURLFailed(let message) {
            throw UtilsFileError.createDatabaseLocationFailed(message: message)
        } catch UtilsFileError.getDatabasesURLFailed {
            throw UtilsFileError.createDatabaseLocationFailed(message: "getDatabasesURLFailed")
        } catch UtilsFileError.moveAllDBSQLiteFailed(let message) {
            throw UtilsFileError.createDatabaseLocationFailed(message: message)
        } catch let error {
            var msg: String = "CreateDatabaseLocation command failed :"
            msg.append(" \(error.localizedDescription)")
            throw UtilsFileError.createDatabaseLocationFailed(message: msg)
        }
    }

    // MARK: - IsFileExist

    class func isDirExist(dirPath: String) -> Bool {
        var isDir: ObjCBool = true
        let fileManager = FileManager.default
        let exists = fileManager.fileExists(atPath: dirPath, isDirectory: &isDir)
        return exists && isDir.boolValue
    }

    // MARK: - moveAllDBSQLite

    class func moveAllDBSQLite(fromURL: URL, dirUrl: URL) throws {
        // get the db list from Documents folder
        do {

            let fileList: [String] = try UtilsFile
                .getFileList(path: fromURL.path,
                             ext: "SQLite.db")
            for file in fileList {
                let fromFileURL: URL = fromURL
                    .appendingPathComponent(file).absoluteURL
                let toFileURL = dirUrl
                    .appendingPathComponent(file).absoluteURL
                let retB: Bool = try UtilsFile
                    .moveFile(pathName: fromFileURL.path,
                              toPathName: toFileURL.path, overwrite: true)
                if !retB {
                    let msg: String = "moveFile command failed :"
                    throw UtilsFileError.moveAllDBSQLiteFailed(message: msg)
                }
            }

        } catch UtilsFileError.getFileListFailed {
            let msg: String = "getFileList command failed :"
            throw UtilsFileError.moveAllDBSQLiteFailed(message: msg)
        } catch UtilsFileError.moveFileFailed {
            let msg: String = "moveFile command failed :"
            throw UtilsFileError.moveAllDBSQLiteFailed(message: msg)
        } catch let error {
            var msg: String = "moveAllDBSQLite command failed :"
            msg.append(" \(error.localizedDescription)")
            throw UtilsFileError.moveAllDBSQLiteFailed(message: msg)
        }

    }
    // MARK: - IsFileExist

    class func isFileExist(filePath: String) -> Bool {
        var ret: Bool = false
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: filePath) {
            ret = true
        }
        return ret
    }
    class func isFileExist(databaseLocation: String, fileName: String) -> Bool {
        var ret: Bool = false
        do {
            let filePath: String =
                try UtilsFile.getFilePath(
                    databaseLocation: databaseLocation,
                    fileName: fileName)
            ret = UtilsFile.isFileExist(filePath: filePath)
            return ret
        } catch UtilsFileError.getFilePathFailed {
            return false
        } catch _ {
            return false
        }
    }

    // MARK: - getFolderURL

    class func getFolderURL(folderPath: String) throws -> URL {
        do {
            let databaseURL = try UtilsFile.getDatabasesUrl().absoluteURL
            var dbPathURL: URL
            let first = folderPath.split(separator: "/", maxSplits: 1)
            if first[0] == "Applications" {
                dbPathURL = try UtilsFile.getApplicationURL().absoluteURL
            } else if first[0] == "Library" {
                dbPathURL = try UtilsFile.getLibraryURL().absoluteURL
            } else if first[0] == "tmp" {
                dbPathURL = UtilsFile.getTmpURL().absoluteURL
            } else if first[0].caseInsensitiveCompare("cache") == .orderedSame {
                dbPathURL = try UtilsFile.getCacheURL().absoluteURL
            } else if first[0] == "Documents" || first[0] == "default" {
                dbPathURL = databaseURL
            } else {
                var msg: String = "getFolderURL command failed :"
                msg.append(" Folder '\(first[0])' not allowed")
                throw UtilsFileError.getFolderURLFailed(message: msg)
            }
            if first.count > 1 {
                dbPathURL = dbPathURL
                    .appendingPathComponent(String(first[1])).absoluteURL
            }
            return dbPathURL
        } catch UtilsFileError.getDatabasesURLFailed {
            throw UtilsFileError.getFolderURLFailed(message: "getDatabasesURLFailed")
        } catch UtilsFileError.getApplicationURLFailed {
            throw UtilsFileError
            .getFolderURLFailed(message: "getApplicationURLFailed")
        } catch let error {
            var msg: String = "getFolderURL command failed :"
            msg.append(" \(error.localizedDescription)")
            throw UtilsFileError.getFolderURLFailed(message: msg)
        }
    }

    // MARK: - GetFilePath

    class func getFilePath(databaseLocation: String,
                           fileName: String) throws -> String {
        do {
            let url: URL = try UtilsFile
                .getFolderURL(folderPath: databaseLocation)
            let dbPath: String = url
                .appendingPathComponent("\(fileName)").path
            return dbPath
        } catch UtilsFileError.getFolderURLFailed(let message) {
            print("Error: getFilePath Failed \(message)")
            throw UtilsFileError.getFilePathFailed
        }
    }

    // MARK: - getDatabasesUrl

    class func getDatabasesUrl() throws -> URL {
        if let path: String = NSSearchPathForDirectoriesInDomains(
            .documentDirectory, .userDomainMask, true
        ).first {
            return NSURL(fileURLWithPath: path) as URL
        } else {
            print("Error: getDatabasesURL did not find the document folder")
            throw UtilsFileError.getDatabasesURLFailed
        }
    }


    // MARK: - getApplicationURL

    class func getApplicationURL() throws -> URL {
        if let path: String = NSSearchPathForDirectoriesInDomains(
            .applicationDirectory, .userDomainMask, true
        ).first {
            return NSURL(fileURLWithPath: path) as URL
        } else {
            print("Error: getApplicationURL did not find the application folder")
            throw UtilsFileError.getApplicationURLFailed
        }
    }


    // MARK: - getCacheURL

    class func getCacheURL() throws -> URL {
        if let path: String = NSSearchPathForDirectoriesInDomains(
            .cachesDirectory, .userDomainMask, true
        ).first {
            return NSURL(fileURLWithPath: path) as URL
        } else {
            print("Error: getCacheURL did not find the cache folder")
            throw UtilsFileError.getCacheURLFailed
        }
    }

    // MARK: - getTmpURL

    class func getTmpURL() -> URL {
        return FileManager.default.temporaryDirectory
    }

    // MARK: - getLibraryURL

    class func getLibraryURL() throws -> URL {
        if let path: String = NSSearchPathForDirectoriesInDomains(
            .libraryDirectory, .userDomainMask, true
        ).first {
            return NSURL(fileURLWithPath: path) as URL
        } else {
            print("Error: getApplicationURL did not find the library folder")
            throw UtilsFileError.getLibraryURLFailed
        }
    }


    // MARK: - GetFileList

    class func getFileList(path: String, ext: String? = nil) throws -> [String] {

        do {
            var files: [String] = []
            let filenames = try FileManager.default
                .contentsOfDirectory(atPath: path)
            for file in filenames {
                if let mExtension = ext {
                    if file.hasSuffix(mExtension) {
                        files.append(file)
                    }
                } else {
                    if file.prefix(1) != "." {
                        files.append(file)
                    }
                }
            }
            return files
        } catch let error {
            print("Error: \(error)")
            throw UtilsFileError.getFileListFailed
        }
    }


    // MARK: - MoveFile

    class func moveFile(pathName: String, toPathName: String, overwrite: Bool) throws -> Bool {
        if pathName.count > 0 && toPathName.count > 0 {
            let isPath = isFileExist(filePath: pathName)
            if isPath {
                do {
                    let isExist: Bool = isFileExist(filePath: toPathName)
                    if !isExist || overwrite {
                        if overwrite && isExist {
                            _ = try deleteFile(filePath: toPathName)
                        }
                        let fileManager = FileManager.default
                        try fileManager.moveItem(atPath: pathName,
                                                 toPath: toPathName)
                    }
                    return true
                } catch let error {
                    print("Error: \(error)")
                    throw UtilsFileError.moveFileFailed
                }
            } else {
                print("Error: MoveFile Failed pathName does not exist")
                throw UtilsFileError.moveFileFailed
            }
        } else {
            print("Error: MoveFile Failed paths count = 0")
            throw UtilsFileError.moveFileFailed
        }
    }
    // MARK: - DeleteFile

    class func deleteFile(filePath: String) throws -> Bool {
        var ret: Bool = false
        do {
            if isFileExist(filePath: filePath) {
                let fileManager = FileManager.default
                do {
                    try fileManager.removeItem(atPath: filePath)
                    ret = true
                } catch let error {
                    print("Error: \(error)")
                    throw UtilsFileError.deleteFileFailed
                }
            }
        } catch let error {
            print("Error: \(error)")
            throw UtilsFileError.deleteFileFailed
        }
        return ret
    }

    // MARK: - DeleteFile

    class func deleteFile(fileName: String,
                          databaseLocation: String) throws -> Bool {
        var ret: Bool = false
        do {
            let filePath: String = try
                getFilePath(databaseLocation: databaseLocation,
                            fileName: fileName)
            ret = try deleteFile(filePath: filePath)
        } catch let error {
            print("Error: \(error)")
            throw UtilsFileError.deleteFileFailed
        }
        return ret
    }

    class func setExcludeFromiCloudBackup(_ fileOrDirectoryURL: inout URL, isExcluded: Bool) throws {
        var values = URLResourceValues()
        values.isExcludedFromBackup = isExcluded
        try fileOrDirectoryURL.setResourceValues(values)
    }
}
// swiftlint:enable type_body_length
// swiftlint:enable file_length
