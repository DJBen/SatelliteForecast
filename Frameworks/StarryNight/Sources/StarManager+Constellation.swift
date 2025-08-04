import Foundation
@preconcurrency import SatelliteKit
@preconcurrency import SQLite

extension StarManager {
    // MARK: - Constellation API
    
    /// Get all constellations
    public func allConstellations() -> Set<Constellation> {
        do {
            var constellations = Set<Constellation>()
            for row in try db.prepare(Tables.constellations) {
                let iau = try row.get(Tables.iauName)
                let con = Constellation(
                    name: try row.get(Tables.constellationName),
                    iAUName: iau,
                    genitive: try row.get(Tables.genitive)
                )
                constellations.insert(con)
            }
            return constellations
        } catch {
            print("Error fetching all constellations: \(error)")
            return []
        }
    }
    
    /// Get a constellation by name
    public func constellation(named name: String) -> Constellation? {
        let query = Tables.constellations.select(
            Tables.constellationName,
            Tables.iauName,
            Tables.genitive
        ).filter(Tables.constellationName == name)
        
        return queryConstellation(query)
    }
    
    /// Get a constellation by IAU abbreviation
    public func constellation(iau: String) -> Constellation? {
        let query = Tables.constellations.select(
            Tables.constellationName,
            Tables.iauName,
            Tables.genitive
        ).filter(Tables.iauName == iau)
        
        return queryConstellation(query)
    }
    
    /// Get constellation connection lines
    public func constellationLines(for constellation: Constellation) async -> [Constellation.Line] {
        guard let lineMappings = getConstellationLineMappings(),
              let lines = lineMappings[constellation.iAUName] else {
            return []
        }
        
        var connectionLines: [Constellation.Line] = []
        for (s1, s2) in lines {
            if let star1 = await getStarByHR(s1), let star2 = await getStarByHR(s2) {
                connectionLines.append(Constellation.Line(star1: star1, star2: star2))
            }
        }
        return connectionLines
    }
    
    /// Get neighboring constellations for a given constellation
    public func neighbors(for constellation: Constellation) -> Set<Constellation> {
        // Define the constellation borders table structure
        let fullBorders = Table("constellation_borders")
        let dbBorderCon = SQLite.Expression<String>("con")
        let dbOppoCon = SQLite.Expression<String>("opposite_con")
        
        var query = fullBorders.select(dbOppoCon)
        if constellation.iAUName == "Ser" {
            query = query.filter(dbBorderCon == "Ser1" || dbBorderCon == "Ser2")
        } else {
            query = query.filter(dbBorderCon == constellation.iAUName)
        }
        
        var constellations: [Constellation] = []
        do {
            for row in try db.prepare(query) {
                let oppoCon = try row.get(dbOppoCon)
                if let neighborConstellation = self.constellation(iau: oppoCon) {
                    constellations.append(neighborConstellation)
                }
            }
        } catch {
            print("Error fetching neighbors for constellation \(constellation.iAUName): \(error)")
        }
        
        return Set<Constellation>(constellations)
    }
    
    // MARK: - Private Constellation Helpers
    
    private func queryConstellation(_ query: QueryType) -> Constellation? {
        do {
            if let row = try db.pluck(query) {
                return Constellation(
                    name: try row.get(Tables.constellationName),
                    iAUName: try row.get(Tables.iauName),
                    genitive: try row.get(Tables.genitive)
                )
            } else {
                return nil
            }
        } catch {
            print("Error querying constellation: \(error)")
            return nil
        }
    }
    
    private func getStarByHR(_ hr: Int) async -> Star? {
        // Search for star with the given HR number
        let query = Tables.starsInfo.filter(Tables.hr == hr)
        
        do {
            if let infoRow = try db.pluck(query) {
                let id = try infoRow.get(Tables.id)
                return star(withId: id)
            }
        } catch {
            print("Error getting star by HR \(hr): \(error)")
        }
        
        return nil
    }
    
    private func getConstellationLineMappings() -> [String: [(Int, Int)]]? {
        guard let constellationLinePath = Bundle.module.path(forResource: "constellation_lines", ofType: "dat") else {
            print("Error: Could not find constellation_lines.dat")
            return nil
        }
        
        do {
            let content = try String(contentsOfFile: constellationLinePath)
            let lines = content.components(separatedBy: "\n").filter { (str) -> Bool in
                return str.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty == false
            }
            var dict: [String: [(Int, Int)]] = [:]
            lines.forEach { (line) in
                let lineComponents: [String] = line.components(separatedBy: " ").filter { $0.isEmpty == false }
                let con = lineComponents[0]
                var starHrs: [(Int, Int)] = []
                for (hr1, hr2) in zip(lineComponents[2..<(lineComponents.endIndex - 1)], lineComponents[3..<(lineComponents.endIndex)]) {
                    if let hr1Int = Int(hr1), let hr2Int = Int(hr2) {
                        starHrs.append((hr1Int, hr2Int))
                    }
                }
                if let connections = dict[con] {
                    dict[con] = connections + starHrs
                } else {
                    dict[con] = starHrs
                }
            }
            return dict
        } catch {
            print("Error reading constellation lines file: \(error)")
            return nil
        }
    }
}
