import Foundation
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
    try Task.checkCancellation()
    let file = directory.appendingPathComponent(category.localFilename).appendingPathExtension(
      "txt")
    func parse(_ data: Data) throws -> [SatelliteInfo] {
      let elements = try OrbitalDataCache.elements(from: data)
      var newest: [UInt: Elements] = [:]
      for element in elements {
        try Task.checkCancellation()
        if newest[element.noradIndex].map({ $0.t₀ < element.t₀ }) ?? true {
          newest[element.noradIndex] = element
        }
      }
      return try newest.values.sorted { $0.noradIndex < $1.noradIndex }.map {
        try SatelliteInfo(elements: $0)
      }
    }
    if !force, let attrs = try? FileManager.default.attributesOfItem(atPath: file.path),
      let date = attrs[.modificationDate] as? Date,
      (0...21600).contains(Date().timeIntervalSince(date)),
      let data = try? Data(contentsOf: file), let info = try? parse(data)
    {
      return info
    }
    do {
      let data = try await fetch(category.url)
      try Task.checkCancellation()
      let info = try parse(data)
      try? data.write(to: file, options: .atomic)
      return info
    } catch {
      if Task.isCancelled || error is CancellationError { throw CancellationError() }
      if let data = try? Data(contentsOf: file), let info = try? parse(data) { return info }
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
            ? 60
            : elevation < 0
              ? 30
              : elevation < 5
                ? 5 : elevation < 10 ? 3 : elevation < 15 ? 2 : elevation < 45 ? 1 : 0.5
      return RealtimePropagationResult(
        noradIndex: info.noradIndex, snapshot: snapshot, satelliteInfo: info,
        nextCheckJulianDate: date + delay * TimeConstants.sec2day)
    }
  }
}
