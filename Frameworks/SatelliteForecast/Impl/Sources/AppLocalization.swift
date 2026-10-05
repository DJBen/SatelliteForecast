import Foundation

/// Strings belong to the implementation package, including those displayed by the host app.
public enum AppLocalization {
    static let bundle = Bundle.module
    public static func text(_ key: String) -> String {
        NSLocalizedString(key, bundle: bundle, comment: "")
    }

    public static func text(_ key: String, locale: Locale) -> String {
        localizedBundle(locale).localizedString(forKey: key, value: nil, table: nil)
    }

    static func localizedBundle(_ locale: Locale) -> Bundle {
        let language = GeographicLocalization.language(for: locale)
        return Bundle.module.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .module
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: Locale.current, arguments: arguments)
    }
}
