import Foundation

public enum WidgetStrings {
    public static let languages = ["en", "es", "fr", "pt-BR", "ru", "zh-Hans", "ja", "ko"]
    private static let bundles: [String: Bundle] = Dictionary(uniqueKeysWithValues: languages.compactMap { language in
        Bundle.module.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:)).map { (language, $0) }
    })
    public static func text(_ key: String, locale: Locale) -> String {
        let language = Bundle.preferredLocalizations(from: languages, forPreferences: [locale.identifier]).first ?? "en"
        return (bundles[language] ?? Bundle.module).localizedString(forKey: key, value: nil, table: nil)
    }
}
