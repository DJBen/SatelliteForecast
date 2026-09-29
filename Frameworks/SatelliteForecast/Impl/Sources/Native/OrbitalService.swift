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
  func skyCatalog() async throws -> (satellites: [SatelliteInfo], refreshAfter: Date) {
    try await catalog(.active)
  }

  /// Lower estimate of time to the observer's horizon plane, not a full pass search.
  /// Bound the approach speed by 12 km/s (above Earth escape speed at the surface)
  /// plus rotation of the horizon plane. Include possible travel over the maximum
  /// sleep window, then wake 20% early and one second ahead of the estimate.
  /// This intentionally over-checks near-horizon and unusual/invalid geometry.
  static func horizonRecheckDelay(elevation: Double, distance: Double, observerAltitude: Double) -> Double {
    guard elevation.isFinite, distance.isFinite, observerAltitude.isFinite,
          distance > 0, elevation < -1, elevation >= -90 else { return 0.5 }
    let maximumDelay = 300.0
    let maximumSpeed = 12.0
    let earthRotation = 7.2921159e-5
    let radiusBound = distance + 6378.137 + abs(observerAltitude) + maximumSpeed * maximumDelay
    let approachSpeed = maximumSpeed + earthRotation * radiusBound
    let belowPlane = -distance * sin(elevation * .pi / 180)
    return max(0.5, min(maximumDelay, 0.8 * belowPlane / approachSpeed - 1))
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

  func catalog(_ category: SatelliteCategory, force: Bool = false) async throws
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
      let elementsToLoad = newest.values.sorted { $0.noradIndex < $1.noradIndex }
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
      let delay = Self.horizonRecheckDelay(elevation: elevation,
          distance: snapshot.position.dist, observerAltitude: observer.alt)
      return RealtimePropagationResult(
        noradIndex: info.noradIndex, snapshot: snapshot, satelliteInfo: info,
        nextCheckJulianDate: date + delay * TimeConstants.sec2day,
        nextSnapshot: elevation >= -1
          ? try? SatelliteSnapshot(satelliteInfo: info, julianDate: date + 5 * TimeConstants.sec2day, observer: observer)
          : nil)
    }
  }
}
