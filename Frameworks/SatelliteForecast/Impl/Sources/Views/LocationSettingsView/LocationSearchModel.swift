import MapKit
import Observation
import SatelliteForecast

/// I/O seams for address search. All MapKit objects stay on the main actor.
@MainActor
public struct LocationSearchClient {
    public var suggestions: @MainActor (String) async throws -> [MKLocalSearchCompletion]
    public var resolve: @MainActor (MKLocalSearchCompletion) async throws -> MKPlacemark
    public var debounce: @MainActor () async throws -> Void

    public init(
        suggestions: @escaping @MainActor (String) async throws -> [MKLocalSearchCompletion],
        resolve: @escaping @MainActor (MKLocalSearchCompletion) async throws -> MKPlacemark,
        debounce: @escaping @MainActor () async throws -> Void = { try await Task.sleep(for: .milliseconds(500)) }
    ) {
        self.suggestions = suggestions
        self.resolve = resolve
        self.debounce = debounce
    }

    public static var live: Self {
        Self(suggestions: { try await CompletionRequest().results(for: $0) }, resolve: { completion in
            let search = MKLocalSearch(request: MKLocalSearch.Request(completion: completion))
            return try await withTaskCancellationHandler {
                let response = try await search.start()
                try Task.checkCancellation()
                guard let placemark = response.mapItems.first?.placemark else {
                    throw SearchError.noLocation
                }
                return placemark
            } onCancel: {
                Task { @MainActor in search.cancel() }
            }
        })
    }
}

private enum SearchError: LocalizedError {
    case noLocation
    var errorDescription: String? { "No location was found for this address. Please try another result." }
}

/// One completer per request prevents callbacks from an old query becoming a new query's results.
@MainActor
private final class CompletionRequest: NSObject, @preconcurrency MKLocalSearchCompleterDelegate {
    private let completer = MKLocalSearchCompleter()
    private var continuation: CheckedContinuation<[MKLocalSearchCompletion], Error>?

    func results(for query: String) async throws -> [MKLocalSearchCompletion] {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                if Task.isCancelled {
                    finish(.failure(CancellationError()))
                } else {
                    completer.delegate = self
                    completer.queryFragment = query
                }
            }
        } onCancel: {
            Task { @MainActor in self.finish(.failure(CancellationError())) }
        }
    }

    private func finish(_ result: Result<[MKLocalSearchCompletion], Error>) {
        let pending = continuation
        continuation = nil
        completer.delegate = nil
        completer.cancel()
        pending?.resume(with: result)
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        finish(.success(completer.results))
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        finish(.failure(error))
    }
}

@MainActor
@Observable
public final class LocationSearchModel {
    public var query = ""
    public private(set) var results: [MKLocalSearchCompletion] = []
    public private(set) var errorMessage: String?
    public private(set) var isSearching = false
    public private(set) var isResolving = false
    public var pendingSelection: LocationResources.Selection?
    @ObservationIgnored private let client: LocationSearchClient
    @ObservationIgnored private var searchGeneration = 0
    @ObservationIgnored private var resolutionGeneration = 0
    @ObservationIgnored private var resolutionTask: Task<Void, Never>?

    public init(client: LocationSearchClient) { self.client = client }
    public convenience init() { self.init(client: .live) }

    /// Called by the view's task(id: query); obsolete tasks cannot publish their results.
    public func search() async {
        guard !Task.isCancelled else { return }
        searchGeneration += 1
        let generation = searchGeneration
        let requestedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        cancelResolution()
        results = []
        errorMessage = nil
        isSearching = !requestedQuery.isEmpty
        defer { if generation == searchGeneration { isSearching = false } }
        guard !requestedQuery.isEmpty else { return }
        var metric: AppAnalytics.Operation?
        defer { metric?.finish("cancelled") }
        do {
            try await client.debounce()
            try Task.checkCancellation()
            metric = AppAnalytics.Operation("location_search", screen: .location)
            let found = try await client.suggestions(requestedQuery)
            try Task.checkCancellation()
            guard generation == searchGeneration, requestedQuery == query.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
            metric?.finish(found.isEmpty ? "empty" : "success", count: found.count)
            results = found
        } catch {
            guard generation == searchGeneration, requestedQuery == query.trimmingCharacters(in: .whitespacesAndNewlines), !Task.isCancelled else { return }
            if !(error is CancellationError) {
                metric?.finish("failure", reason: "search_failed")
                errorMessage = error.localizedDescription
            }
        }
    }

    public func select(_ completion: MKLocalSearchCompletion) {
        resolutionTask?.cancel()
        resolutionTask = Task { await resolve(completion) }
    }

    public func resolve(_ completion: MKLocalSearchCompletion) async {
        guard !Task.isCancelled else { return }
        let requestedQuery = query
        resolutionGeneration += 1
        let generation = resolutionGeneration
        pendingSelection = nil
        errorMessage = nil
        isResolving = true
        defer { if generation == resolutionGeneration { isResolving = false } }
        let metric = AppAnalytics.Operation("location_resolve", screen: .location)
        defer { metric.finish("cancelled") }
        do {
            let placemark = try await client.resolve(completion)
            try Task.checkCancellation()
            guard generation == resolutionGeneration, requestedQuery == query else { return }
            metric.finish("success")
            pendingSelection = .custom(completion, placemark)
        } catch {
            guard generation == resolutionGeneration, requestedQuery == query, !Task.isCancelled else { return }
            if !(error is CancellationError) {
                metric.finish("failure", reason: "resolve_failed")
                errorMessage = error.localizedDescription
            }
        }
    }

    public func useCurrentLocation() {
        cancelResolution()
        pendingSelection = .currentLocation
    }

    private func cancelResolution() {
        resolutionGeneration += 1
        resolutionTask?.cancel()
        resolutionTask = nil
        isResolving = false
        pendingSelection = nil
    }

    public func cancel() {
        searchGeneration += 1
        isSearching = false
        cancelResolution()
    }
}
