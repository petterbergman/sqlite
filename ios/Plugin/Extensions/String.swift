//
//  String.swift
//  Capacitor
//
//  Created by  Quéau Jean Pierre on 20/04/2021.
//

import Foundation

extension String {
    public func indicesOf(string: String, fromIdx: Int? = 0) -> [Int] {
        var indices = [Int]()
        var searchStartIndex = self.startIndex
        if let fIdx = fromIdx {
            if fIdx != 0 {
                searchStartIndex = self.index(self.startIndex, offsetBy: fIdx)
            }
        }

        while searchStartIndex < self.endIndex,
              let range = self.range(of: string, options: .caseInsensitive, range: searchStartIndex..<self.endIndex),
              !range.isEmpty {
            let index = distance(from: self.startIndex, to: range.lowerBound)
            indices.append(index)
            searchStartIndex = range.upperBound
        }

        return indices
    }
    public func stringRange(fromIdx: Int, toIdx: Int) -> Substring {
        let startIndex = self.index(self.startIndex, offsetBy: fromIdx)
        let stopIndex = self.index(self.startIndex, offsetBy: toIdx)
        return self[startIndex..<stopIndex]
    }
}
