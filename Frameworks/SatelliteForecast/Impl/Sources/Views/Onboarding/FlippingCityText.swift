import Foundation
import SwiftUI

// Add city data structure
private struct CityData {
    enum LayoutType {
        case vertical, horizontalPrefix
    }
    static let cities: [String: [String]] = [
        "en": ["New York", "San Francisco", "London", "Los Angeles", "Austin", "Sydney", "Toronto", "Berlin", "Singapore", "Cape Town"],
        "fr": [
            "Paris", "Lyon", "Marseille", "Toulouse", "Nice", "Bordeaux",
            // Major French Canadian cities
            "Montréal", "Québec",
        ],
        "fr_CA": [
            "Montréal", "Québec", "Laval", "Gatineau", "Longueuil", "Sherbrooke", "Trois-Rivières", "Saguenay"
        ],
        "es": [
            // Major cities in Spain
            "Madrid", "Barcelona",
            // Major Spanish-speaking cities in the Americas
            "Ciudad de México", "Buenos Aires", "Lima", "Bogotá", "Santiago", "Caracas", "Quito", "Guadalajara", "Monterrey", "Medellín", "La Paz"
        ],
        "pt": ["São Paulo", "Rio de Janeiro", "Brasília", "Salvador", "Fortaleza", "Belo Horizonte", "Manaus", "Curitiba"],
        "ru": ["Москва", "Санкт-Петербург", "Новосибирск", "Екатеринбург", "Казань", "Нижний Новгород", "Челябинск", "Самара", "Омск", "Ростов-на-Дону"],
        "zh-Hans": ["北京", "上海", "广州", "深圳", "成都", "杭州", "南京", "重庆", "西安"],
        "ja": ["東京", "大阪", "札幌", "名古屋", "福岡", "横浜", "京都", "神戸", "広島", "仙台"],
        "ko": ["서울", "부산", "인천", "대구", "광주", "대전", "울산", "수원", "창원", "고양"]
    ]
    
    static let localizedText: [String: (prefix: String, suffix: String, layout: LayoutType)] = [
        "en": ("View ISS from", "", .vertical),
        "fr": ("Voir l'ISS depuis", "", .vertical),
        "es": ("Ver la ISS desde", "", .vertical),
        "pt": ("Ver a ISS de", "", .vertical),
        "ru": ("Посмотреть МКС из", "", .vertical),
        "zh-Hans": ("我在", "遇见天宫空间站", .horizontalPrefix),
        "ja": ("ISSを", "から見る", .horizontalPrefix),
        "ko": ("ISS를", "에서 보기", .horizontalPrefix)
    ]
    
    static func getCities(for locale: String) -> [String] {
        return cities[locale] ?? cities["en"]!
    }
    
    static func getLocalizedText(for locale: String) -> (prefix: String, suffix: String, layout: LayoutType) {
        return localizedText[locale] ?? localizedText["en"]!
    }
}

// Add flipping text view
struct FlippingCityText: View {
    private let cities: [String]
    private let localizedText: (prefix: String, suffix: String)
    private let layout: CityData.LayoutType

    init() {
        let currentLocale = Locale.current.identifier
        let localeKey: String

        if currentLocale.hasPrefix("fr") {
            localeKey = "fr"
        } else if currentLocale.hasPrefix("es") {
            localeKey = "es"
        } else if currentLocale.hasPrefix("pt") {
            localeKey = "pt"
        } else if currentLocale.hasPrefix("ru") {
            localeKey = "ru"
        } else if currentLocale.hasPrefix("zh") {
            localeKey = "zh-Hans"
        } else if currentLocale.hasPrefix("ja") {
            localeKey = "ja"
        } else if currentLocale.hasPrefix("ko") {
            localeKey = "ko"
        } else {
            localeKey = "en"
        }

        self.cities = CityData.getCities(for: localeKey)
        let (prefix, suffix, layout) = CityData.getLocalizedText(for: localeKey)
        self.localizedText = (prefix, suffix)
        self.layout = layout
    }

    var body: some View {
        VStack(spacing: 8) {
            switch layout {
            case .horizontalPrefix:
                HStack(spacing: 0) {
                    if !localizedText.prefix.isEmpty {
                        Text(localizedText.prefix)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                    FlippingTextView(items: cities)
                }
                if !localizedText.suffix.isEmpty {
                    Text(localizedText.suffix)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }
            case .vertical:
                if !localizedText.prefix.isEmpty {
                    Text(localizedText.prefix)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }
                FlippingTextView(items: cities)
                if !localizedText.suffix.isEmpty {
                    Text(localizedText.suffix)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(.vertical, 16)
    }
}

