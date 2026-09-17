import Foundation

/// Explicit locale selection also supports SwiftUI previews and per-app language changes.
/// Templates are complete phrases: never inflect or concatenate translated place names.
enum GeographicLocalization {
    static func language(for locale: Locale) -> String {
        let parts = locale.identifier.replacingOccurrences(of: "_", with: "-").lowercased().split(separator: "-")
        switch parts.first {
        case "fr": return "fr"
        case "es": return "es"
        case "pt": return "pt-BR"
        case "ru": return "ru"
        case "ja": return "ja"
        case "ko": return "ko"
        case "zh":
            return parts.contains("hant") || parts.contains("tw") || parts.contains("hk") || parts.contains("mo") ? "en" : "zh-Hans"
        default: return "en"
        }
    }

    static func nameLanguage(for locale: Locale) -> String {
        switch language(for: locale) {
        case "pt-BR": return "pt"
        case "zh-Hans": return "zh"
        case let language: return language
        }
    }

    static func text(_ key: String, locale: Locale, _ arguments: String...) -> String {
        let language = language(for: locale)
        let path = Bundle.module.path(forResource: language, ofType: "lproj")
        let bundle = path.flatMap(Bundle.init(path:)) ?? Bundle.module
        let fullKey = "geography.\(key)"
        let english = Bundle.module.path(forResource: "en", ofType: "lproj").flatMap(Bundle.init(path:)) ?? Bundle.module
        let fallback = english.localizedString(forKey: fullKey, value: nil, table: "Localizable")
        let format = bundle.localizedString(forKey: fullKey, value: fallback, table: "Localizable")
        return String(format: format, locale: locale, arguments: arguments)
    }
}
