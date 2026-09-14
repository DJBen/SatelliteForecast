import Foundation
import QSMag
import SatelliteCatalog
import SatelliteCatalogImpl_SQLite
import SatelliteForecast
import SatelliteKit

extension SatelliteInfo {
    public init(elements: Elements) throws {
        let satCat = try SatCat.with(noradCatID: Int(elements.noradIndex))
        let ucsSat = try UCSSat.with(noradCatID: Int(elements.noradIndex))
        let qsMag = QSMag.with(noradIndex: elements.noradIndex)
        self.init(
            elements: elements,
            satCat: satCat,
            ucsSat: ucsSat,
            qsMag: qsMag
        )
    }
}

public extension Elements {
    static func load(chunk: String) throws -> [Elements] {
        var tle = [String]()
        var result = [Elements]()
        let lines = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isNewline)
        for (i, line) in lines.enumerated() {
            if tle.count >= 3 && i % 3 == 0 {
                result.append(try Elements(tle[0], tle[1], tle[2]))
                tle = [String(line)]
            } else {
                tle.append(String(line))
            }
        }
        if tle.count == 3 {
            result.append(try Elements(tle[0], tle[1], tle[2]))
        }
        return result
    }

    init(raw: String) throws {
        let lines = raw.components(separatedBy: .newlines)
        try self.init(lines[0], lines[1], lines[2])
    }
}
