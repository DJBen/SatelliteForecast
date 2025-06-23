//
//  QSMag.swift
//  QSMag
//
//  Created by Ben Lu on 2/16/22.
//

import Foundation

/// https://www.prismnet.com/~mmccants/
public struct QSMag : Sendable {
    public let noradIndex: UInt
    public let designation: String
    public let name: String
    public let magnitude: Double?
    public let rcs: Double?

    public static let localData: [UInt: QSMag] = loadLocalData()

    public static func loadLocalData() -> [UInt: QSMag] {
        guard let filePath = Bundle.module.path(forResource: "qs", ofType: "mag") else {
            fatalError("qs.mag file not found")
        }
        let contents = try! String(contentsOfFile: filePath)
        let lines = contents.split(separator: "\r\n")
        let noradRange = 0..<5
        let designationRange = 8..<16
        let nameRange = 18..<32
        let magRange = 33..<38
        let rcsRange = 51..<54
        var results: [UInt: QSMag] = [:]

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.isEmpty {
                continue
            }

            let noradIndex = UInt(trimmedLine.substring(range: noradRange)!)!
            if noradIndex == 1 || noradIndex == 99999 {
                continue
            }
            let qsMag = QSMag(
                noradIndex: noradIndex,
                designation: trimmedLine.substring(range: designationRange)!,
                name: trimmedLine.substring(range: nameRange)!,
                magnitude: trimmedLine.substring(range: magRange).flatMap { Double($0) },
                rcs: trimmedLine.substring(range: rcsRange).flatMap { Double($0) }
            )
            results[noradIndex] = qsMag
        }

        return results
    }

    public static func with(noradIndex: UInt) -> QSMag? {
        return localData[noradIndex]
    }
}

extension QSMag: Equatable {}

fileprivate extension String {
    func substring(range: Range<Int>) -> String? {
        guard range.startIndex < lengthOfBytes(using: .utf8) else {
            return nil
        }
        var endIndex = range.endIndex
        if range.endIndex > lengthOfBytes(using: .utf8) {
            endIndex = lengthOfBytes(using: .utf8)
        }
        return String(self[index(startIndex, offsetBy: range.startIndex)..<index(startIndex, offsetBy: endIndex)]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
