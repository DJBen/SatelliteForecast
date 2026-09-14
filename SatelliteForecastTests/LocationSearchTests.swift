import MapKit
import XCTest
import SatelliteForecast
@testable import SatelliteForecastImpl

@MainActor
final class LocationSearchTests: XCTestCase {
    func testAlarmDeletionUsesDisplayedOrderAndStableIdentifiers() async throws {
        let fixture = try Fixture(catalog: await AppStarCatalog.load())
        let notification = PassNotification(pass: fixture.passes[0].pass, satelliteName: "ISS",
            category: .iss, observer: fixture.observer, timing: .rise, timeOffset: 0)
        var deleted = Set<String>()
        let view = AlarmSettingsView(notifications: [
            ScheduledPassNotification(id: "b", notification: notification),
            ScheduledPassNotification(id: "a", notification: notification)
        ], deleteNotifications: { deleted = $0 })
        view.deleteAlarms(at: IndexSet(integer: 0))
        XCTAssertEqual(deleted, ["a"])
        deleted = []
        view.deleteAlarms(at: IndexSet(integer: 99))
        XCTAssertTrue(deleted.isEmpty)
    }

    func testLateSuggestionsCannotReplaceNewerQuery() async {
        let firstStarted = expectation(description: "First query started")
        var first: CheckedContinuation<[MKLocalSearchCompletion], Error>?
        let latest = MKLocalSearchCompletion()
        let model = LocationSearchModel(client: .init(suggestions: { query in
            if query == "first" {
                return try await withCheckedThrowingContinuation {
                    first = $0
                    firstStarted.fulfill()
                }
            }
            return [latest]
        }, resolve: { _ in throw Failure.offline }, debounce: {}))
        model.query = "first"
        let old = Task { await model.search() }
        await fulfillment(of: [firstStarted], timeout: 1)
        model.query = "second"
        await model.search()
        first?.resume(returning: [MKLocalSearchCompletion()])
        await old.value
        XCTAssertEqual(model.results.count, 1)
        XCTAssertTrue(model.results.first === latest)
        XCTAssertFalse(model.isSearching)
    }

    func testCancelledSearchCannotPublishOrShowError() async {
        let started = expectation(description: "Query started")
        var pending: CheckedContinuation<[MKLocalSearchCompletion], Error>?
        let model = LocationSearchModel(client: .init(suggestions: { _ in
            try await withCheckedThrowingContinuation { pending = $0; started.fulfill() }
        }, resolve: { _ in throw Failure.offline }, debounce: {}))
        model.query = "query"
        let task = Task { await model.search() }
        await fulfillment(of: [started], timeout: 1)
        task.cancel()
        pending?.resume(returning: [MKLocalSearchCompletion()])
        await task.value
        XCTAssertTrue(model.results.isEmpty)
        XCTAssertNil(model.errorMessage)
        XCTAssertFalse(model.isSearching)
    }

    func testFailureRecoversAndEmptyQueryClearsResultsWithoutRequest() async {
        var calls = 0
        let model = LocationSearchModel(client: .init(suggestions: { _ in
            calls += 1
            if calls == 1 { throw Failure.offline }
            return [MKLocalSearchCompletion()]
        }, resolve: { _ in throw Failure.offline }, debounce: {}))
        model.query = "query"
        await model.search()
        XCTAssertNotNil(model.errorMessage)
        await model.search()
        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(model.results.count, 1)
        model.query = "  "
        await model.search()
        XCTAssertEqual(calls, 2)
        XCTAssertTrue(model.results.isEmpty)
    }

    func testLateAddressResolutionCannotConfirmWrongLocation() async {
        let started = expectation(description: "First resolution started")
        var pending: CheckedContinuation<MKPlacemark, Error>?
        let first = MKLocalSearchCompletion(), second = MKLocalSearchCompletion()
        let model = LocationSearchModel(client: .init(suggestions: { _ in [] }, resolve: { completion in
            if completion === first {
                return try await withCheckedThrowingContinuation { pending = $0; started.fulfill() }
            }
            return MKPlacemark(coordinate: .init(latitude: 20, longitude: 30))
        }, debounce: {}))
        let old = Task { await model.resolve(first) }
        await fulfillment(of: [started], timeout: 1)
        await model.resolve(second)
        pending?.resume(returning: MKPlacemark(coordinate: .init(latitude: 1, longitude: 2)))
        await old.value
        guard case let .custom(completion, placemark) = model.pendingSelection else { return XCTFail("Missing selection") }
        XCTAssertTrue(completion === second)
        XCTAssertEqual(placemark.coordinate.latitude, 20)
    }

    func testLeavingScreenDiscardsPendingConfirmation() async {
        let started = expectation(description: "Resolution started")
        var pending: CheckedContinuation<MKPlacemark, Error>?
        let model = LocationSearchModel(client: .init(suggestions: { _ in [] }, resolve: { _ in
            try await withCheckedThrowingContinuation { pending = $0; started.fulfill() }
        }, debounce: {}))
        let task = Task { await model.resolve(MKLocalSearchCompletion()) }
        await fulfillment(of: [started], timeout: 1)
        model.cancel()
        pending?.resume(returning: MKPlacemark(coordinate: .init(latitude: 1, longitude: 2)))
        await task.value
        XCTAssertNil(model.pendingSelection)
        XCTAssertFalse(model.isResolving)
    }
}

private enum Failure: Error { case offline }
