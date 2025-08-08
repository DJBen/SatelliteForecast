import StarryNight
@preconcurrency import SatelliteKit

actor StarManagerMock: StarManaging {
    func stars(maximumMagnitude: Double) -> [StarryNight.Star] {
        []
    }
    
    func brightestStars() -> [StarryNight.Star] {
        []
    }
    
    func stars(forH3Level level: Int, maximumMagnitude magCutoff: Double?) -> [StarryNight.Star] {
        []
    }
    
    func stars(inH3Cell h3Index: String, level: Int, maximumMagnitude magCutoff: Double?) -> [StarryNight.Star] {
        []
    }
    
    func stars(inViewport vertices: [(latitude: Double, longitude: Double)], maximumMagnitude magCutoff: Double?) -> [StarryNight.Star] {
        []
    }
    
    func closestStar(to coordinate: SatelliteKit.Vector, maximumMagnitude magCutoff: Double?, maximumAngularDistance angularDistance: Double?) -> StarryNight.Star? {
        nil
    }
    
    func searchStars(matching name: String) -> [StarryNight.Star] {
        []
    }
    
    func star(withId id: Int) -> StarryNight.Star? {
        nil
    }
    
    func starInfo(forId id: Int) -> StarryNight.StarInfo? {
        nil
    }
    
    func starWithInfo(id: Int) -> StarryNight.Star? {
        nil
    }
    
    func allConstellations() -> Set<StarryNight.Constellation> {
        []
    }
    
    func constellation(named name: String) -> StarryNight.Constellation? {
        nil
    }
    
    func constellation(iau: String) -> StarryNight.Constellation? {
        nil
    }
    
    func constellationLines(for constellation: StarryNight.Constellation) async -> [StarryNight.Constellation.Line] {
        []
    }
    
    func neighbors(for constellation: StarryNight.Constellation) -> Set<StarryNight.Constellation> {
        []
    }
    
    
}
