import Foundation
import SwiftUI

// Add city data structure
private struct CityData {
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
        "pt_BR": ["São Paulo", "Rio de Janeiro", "Brasília", "Salvador", "Fortaleza", "Belo Horizonte", "Manaus", "Curitiba"],
        "zh_Hans": ["北京", "上海", "广州", "深圳", "成都", "杭州", "南京", "重庆", "西安"]
    ]
    
    static let localizedText: [String: (prefix: String, suffix: String)] = [
        "en": ("View ISS at", ""),
        "fr": ("Voir l'ISS à", ""),
        "fr_CA": ("Voir l'ISS à", ""),
        "es": ("Ver la ISS en", ""),
        "pt_BR": ("Ver a ISS em", ""),
        "zh_Hans": ("我在", "遇见天宫空间站")
    ]
    
    static func getCities(for locale: String) -> [String] {
        return cities[locale] ?? cities["en"] ?? []
    }
    
    static func getLocalizedText(for locale: String) -> (prefix: String, suffix: String) {
        return localizedText[locale] ?? localizedText["en"] ?? ("View ISS at", "")
    }
}

// Add flipping text view
struct FlippingCityText: View {
    @State private var currentCityIndex = 0
    @State private var nextCityIndex = 1
    @State private var currentOffset: CGFloat = 0
    @State private var nextOffset: CGFloat = 60
    @State private var currentOpacity: Double = 1.0
    @State private var nextOpacity: Double = 0.0
    @State private var timer: Timer?
    
    private let cities: [String]
    private let localizedText: (prefix: String, suffix: String)
    
    init() {
        let currentLocale = Locale.current.identifier
        let localeKey: String
        
        if currentLocale.hasPrefix("fr") {
            localeKey = "fr"
        } else if currentLocale.hasPrefix("es") {
            localeKey = "es"
        } else if currentLocale.hasPrefix("pt_BR") || currentLocale.hasPrefix("pt-BR") {
            localeKey = "pt_BR"
        } else if currentLocale.hasPrefix("zh_Hans") || currentLocale.hasPrefix("zh-Hans") {
            localeKey = "zh_Hans"
        } else {
            localeKey = "en"
        }
        
        self.cities = CityData.getCities(for: localeKey)
        self.localizedText = CityData.getLocalizedText(for: localeKey)
        if !cities.isEmpty {
            self.nextCityIndex = 1 % cities.count
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Prefix text (for most languages)
            if !localizedText.prefix.isEmpty {
                Text(localizedText.prefix)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            
            // Flipping city text
            ZStack {
                // Current text
                Text(cities.isEmpty ? "Cities" : cities[currentCityIndex])
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .offset(y: currentOffset)
                    .opacity(currentOpacity)
                
                // Next text (initially hidden below)
                Text(cities.isEmpty ? "Cities" : cities[nextCityIndex])
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .offset(y: nextOffset)
                    .opacity(nextOpacity)
            }
            .frame(height: 50)
            .clipped()
            
            // Suffix text (for Chinese)
            if !localizedText.suffix.isEmpty {
                Text(localizedText.suffix)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 16)
        .onAppear {
            startFlipping()
        }
        .onDisappear {
            stopFlipping()
        }
    }
    
    private func startFlipping() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
            guard !cities.isEmpty else { return }
            
            // Animate current text moving up and fading out
            // while next text moves up from below and fades in
            withAnimation(.easeInOut(duration: 0.5)) {
                currentOffset = -60
                currentOpacity = 0.0
                nextOffset = 0
                nextOpacity = 1.0
            }
            
            // After animation completes, swap the roles and prepare for next cycle
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // Swap current and next indices
                currentCityIndex = nextCityIndex
                nextCityIndex = (nextCityIndex + 1) % cities.count
                
                // Instantly reset positions for next cycle
                currentOffset = 0
                currentOpacity = 1.0
                nextOffset = 60
                nextOpacity = 0.0
            }
        }
    }
    
    private func stopFlipping() {
        timer?.invalidate()
        timer = nil
    }
}
