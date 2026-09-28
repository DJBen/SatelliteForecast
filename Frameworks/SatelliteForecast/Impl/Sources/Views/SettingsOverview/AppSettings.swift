import Observation

/// Shared appearance options. Owned by the app, independent of the legacy store.
/// Values remain session-scoped, matching the existing application behavior.
@MainActor
@Observable
public final class AppSettings {
    public var isNightModeOn: Bool

    public init(isNightModeOn: Bool = false) {
        self.isNightModeOn = isNightModeOn
    }
}
