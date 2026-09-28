import Foundation
import QSMag
import SatelliteForecast
import SatelliteKit

/// Serializes metadata lookup, file access, and prediction work away from UI execution.
public actor OrbitalService {
  private let directory: URL
  private let fetch: @Sendable (URL) async throws -> Data
  public init(
    directory: URL = OrbitalDataCache.directory,
    fetch: @escaping @Sendable (URL) async throws -> Data = { url in
      var request = URLRequest(url: url)
      request.timeoutInterval = 20
      let (data, response) = try await URLSession.shared.data(for: request)
      guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode)
      else {
        throw ForecastServiceError.invalidResponse
      }
      return data
    }
  ) {
    self.directory = directory
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    self.fetch = fetch
  }

  public func satellites(_ category: SatelliteCategory, force: Bool = false) async throws
    -> [SatelliteInfo]
  {
    try await catalog(category, force: force).satellites
  }

  /// Carry the disk cache's original expiry into in-memory consumers. Reading a
  /// five-hour-old file must not grant its elements another six hours of freshness.
  static let liveSkyLimit = 100

  func skyCatalog() async throws -> (satellites: [SatelliteInfo], refreshAfter: Date) {
    try await catalog(.brightest100, liveSky: true)
  }

  /// The small visual dataset is ranked before any SQLite metadata lookup.
  static func liveSkyCandidates(_ elements: [Elements]) -> [Elements] {
    elements.filter { $0.orbitTypeByAltitude == .leo }.sorted {
      let a = QSMag.with(noradIndex: $0.noradIndex)?.magnitude ?? .infinity
      let b = QSMag.with(noradIndex: $1.noradIndex)?.magnitude ?? .infinity
      return a == b ? $0.noradIndex < $1.noradIndex : a < b
    }.prefix(liveSkyLimit).map { $0 }
  }

  static func enrich(_ elements: [Elements],
                     makeInfo: (Elements) async throws -> SatelliteInfo = { try await SatelliteInfo.load(elements: $0) }) async throws -> [SatelliteInfo] {
    var result: [SatelliteInfo] = []
    result.reserveCapacity(elements.count)
    for element in elements {
      try Task.checkCancellation()
      result.append(try await makeInfo(element))
    }
    try Task.checkCancellation()
    return result
  }

  func catalog(_ category: SatelliteCategory, force: Bool = false, liveSky: Bool = false) async throws
    -> (satellites: [SatelliteInfo], refreshAfter: Date)
  {
    try Task.checkCancellation()
    let file = directory.appendingPathComponent(category.localFilename).appendingPathExtension(
      "txt")
    func parse(_ data: Data) async throws -> [SatelliteInfo] {
      let elements = try OrbitalDataCache.elements(from: data)
      var newest: [UInt: Elements] = [:]
      for element in elements {
        try Task.checkCancellation()
        if newest[element.noradIndex].map({ $0.t₀ < element.t₀ }) ?? true {
          newest[element.noradIndex] = element
        }
      }
      let elementsToLoad = liveSky ? Self.liveSkyCandidates(Array(newest.values))
        : newest.values.sorted { $0.noradIndex < $1.noradIndex }
      return try await Self.enrich(elementsToLoad)
    }
    if !force, let attrs = try? FileManager.default.attributesOfItem(atPath: file.path),
      let date = attrs[.modificationDate] as? Date,
      (0...21600).contains(Date().timeIntervalSince(date)),
      let data = try? Data(contentsOf: file), let info = try? await parse(data)
    {
      return (info, date.addingTimeInterval(21600))
    }
    try Task.checkCancellation()
    do {
      let data = try await fetch(category.url)
      try Task.checkCancellation()
      let info = try await parse(data)
      try? data.write(to: file, options: .atomic)
      return (info, Date().addingTimeInterval(21600))
    } catch {
      if Task.isCancelled || error is CancellationError { throw CancellationError() }
      if let data = try? Data(contentsOf: file), let info = try? await parse(data) {
        // Keep offline data usable, with a short retry delay rather than a new freshness window.
        return (info, Date().addingTimeInterval(60))
      }
      try Task.checkCancellation()
      throw error
    }
  }
  public func search(_ satellites: [SatelliteInfo], text: String) throws -> [SatelliteInfo] {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy"
    return try satellites.filter { info in
      try Task.checkCancellation()
      var fields = [String(info.noradIndex), info.elements.commonName]
      if let cat = info.satCat {
        fields += [cat.cosparID, cat.launchSite.code, formatter.string(from: cat.launchDate)]
      }
      if let ucs = info.ucsSat { fields += [ucs.name, ucs.countryOfOperatorOrOwner] }
      return fields.contains { $0.lowercased().contains(text) }
    }
  }
  public func snapshots(info: SatelliteInfo, observer: LatLonAlt, range: ClosedRange<Double>) throws
    -> [SatelliteSnapshot]
  {
    try info.generateSnapshots(observer: observer, julianDateRange: range, interval: 30)
  }
  public func trails(info: SatelliteInfo, observer: LatLonAlt, range: ClosedRange<Double>) throws
    -> SatelliteTrails
  {
    let snapshots = try info.generateSnapshots(
      observer: observer, julianDateRange: range, interval: 30)
    let passes = try info.findPasses(
      observer: observer, coarseSnapshots: snapshots, qsMag: info.qsMag,
      crossSectionArea: info.satCat?.rcs)
    try Task.checkCancellation()
    return SatelliteTrails(observer: observer, snapshots: snapshots, passSnapshots: passes)
  }
  public func realtime(satellites: [SatelliteInfo], observer: LatLonAlt, date: Double) throws
    -> [RealtimePropagationResult]
  {
    try satellites.compactMap { info in
      try Task.checkCancellation()
      guard
        let snapshot = try? SatelliteSnapshot(
          satelliteInfo: info, julianDate: date, observer: observer)
      else { return nil }
      let elevation = snapshot.position.elev
      let delay: Double =
        elevation < -30
        ? 300
        : elevation < -15
          ? 120
          : elevation < -5
            ? 15
            : elevation < 0
              ? 5
              : elevation < 5
                ? 5 : elevation < 10 ? 3 : elevation < 15 ? 2 : elevation < 45 ? 1 : 0.5
      return RealtimePropagationResult(
        noradIndex: info.noradIndex, snapshot: snapshot, satelliteInfo: info,
        nextCheckJulianDate: date + min(delay, elevation >= -1 ? 1 : delay) * TimeConstants.sec2day,
        nextSnapshot: elevation >= -1
          ? try? SatelliteSnapshot(satelliteInfo: info, julianDate: date + 5 * TimeConstants.sec2day, observer: observer)
          : nil)
    }
  }
}
