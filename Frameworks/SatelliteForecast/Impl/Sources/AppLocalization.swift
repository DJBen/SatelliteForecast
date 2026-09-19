import Foundation

/// Strings belong to the implementation package, including those displayed by the host app.
public enum AppLocalization {
    static let bundle = Bundle.module
    public static func text(_ key: String) -> String {
        NSLocalizedString(key, bundle: bundle, comment: "")
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: Locale.current, arguments: arguments)
    }
}
