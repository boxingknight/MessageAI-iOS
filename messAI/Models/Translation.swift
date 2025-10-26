import Foundation

/// Supported languages for translation
enum LanguageCode: String, CaseIterable, Codable {
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case portuguese = "pt"
    case russian = "ru"
    case japanese = "ja"
    case korean = "ko"
    case chinese = "zh"
    case arabic = "ar"
    case hindi = "hi"
    case dutch = "nl"
    case swedish = "sv"
    case norwegian = "no"
    case danish = "da"
    case finnish = "fi"
    case polish = "pl"
    
    /// Human-readable language name
    var displayName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Spanish"
        case .french: return "French"
        case .german: return "German"
        case .italian: return "Italian"
        case .portuguese: return "Portuguese"
        case .russian: return "Russian"
        case .japanese: return "Japanese"
        case .korean: return "Korean"
        case .chinese: return "Chinese (Simplified)"
        case .arabic: return "Arabic"
        case .hindi: return "Hindi"
        case .dutch: return "Dutch"
        case .swedish: return "Swedish"
        case .norwegian: return "Norwegian"
        case .danish: return "Danish"
        case .finnish: return "Finnish"
        case .polish: return "Polish"
        }
    }
    
    /// Language flag emoji (approximate)
    var flagEmoji: String {
        switch self {
        case .english: return "🇺🇸"
        case .spanish: return "🇪🇸"
        case .french: return "🇫🇷"
        case .german: return "🇩🇪"
        case .italian: return "🇮🇹"
        case .portuguese: return "🇵🇹"
        case .russian: return "🇷🇺"
        case .japanese: return "🇯🇵"
        case .korean: return "🇰🇷"
        case .chinese: return "🇨🇳"
        case .arabic: return "🇸🇦"
        case .hindi: return "🇮🇳"
        case .dutch: return "🇳🇱"
        case .swedish: return "🇸🇪"
        case .norwegian: return "🇳🇴"
        case .danish: return "🇩🇰"
        case .finnish: return "🇫🇮"
        case .polish: return "🇵🇱"
        }
    }
    
    /// Most commonly used languages (for quick access)
    static let popularLanguages: [LanguageCode] = [
        .english, .spanish, .french, .german, .chinese, .japanese
    ]
}

/// Translation method used
enum TranslationMethod: String, Codable {
    case gpt4 = "gpt-4"
    case cached = "cached"
    
    var displayName: String {
        switch self {
        case .gpt4: return "AI Translation"
        case .cached: return "Cached"
        }
    }
}

/// Translation result from AI service
struct TranslationResult: Codable, Identifiable {
    let id = UUID()
    let translatedText: String
    let detectedSourceLanguage: LanguageCode
    let targetLanguage: LanguageCode
    let confidence: Double
    let translationMethod: TranslationMethod
    let processingTimeMs: Int
    let tokensUsed: Int
    let cost: Double
    let timestamp: Date
    
    /// Initialize from Cloud Function response
    init?(from dictionary: [String: Any]) {
        guard let translatedText = dictionary["translatedText"] as? String,
              let detectedSourceLanguageString = dictionary["detectedSourceLanguage"] as? String,
              let detectedSourceLanguage = LanguageCode(rawValue: detectedSourceLanguageString),
              let targetLanguageString = dictionary["targetLanguage"] as? String,
              let targetLanguage = LanguageCode(rawValue: targetLanguageString),
              let confidence = dictionary["confidence"] as? Double,
              let translationMethodString = dictionary["translationMethod"] as? String,
              let translationMethod = TranslationMethod(rawValue: translationMethodString),
              let processingTimeMs = dictionary["processingTimeMs"] as? Int,
              let tokensUsed = dictionary["tokensUsed"] as? Int,
              let cost = dictionary["cost"] as? Double else {
            print("❌ TranslationResult: Failed to parse from dictionary")
            print("   Dictionary: \(dictionary)")
            return nil
        }
        
        self.translatedText = translatedText
        self.detectedSourceLanguage = detectedSourceLanguage
        self.targetLanguage = targetLanguage
        self.confidence = confidence
        self.translationMethod = translationMethod
        self.processingTimeMs = processingTimeMs
        self.tokensUsed = tokensUsed
        self.cost = cost
        self.timestamp = Date()
    }
    
    /// Confidence level description
    var confidenceDescription: String {
        switch confidence {
        case 0.9...1.0: return "Very High"
        case 0.7..<0.9: return "High"
        case 0.5..<0.7: return "Medium"
        case 0.3..<0.5: return "Low"
        default: return "Very Low"
        }
    }
    
    /// Processing time description
    var processingTimeDescription: String {
        if processingTimeMs < 1000 {
            return "\(processingTimeMs)ms"
        } else {
            let seconds = Double(processingTimeMs) / 1000.0
            return String(format: "%.1fs", seconds)
        }
    }
    
    /// Cost description in cents
    var costDescription: String {
        let cents = cost * 100
        if cents < 0.01 {
            return "<$0.01"
        } else {
            return String(format: "$%.3f", cost)
        }
    }
}

/// Translation request data
struct TranslationRequest: Codable {
    let messageText: String
    let targetLanguage: LanguageCode
    let sourceLanguage: LanguageCode?
    let conversationId: String
    let messageId: String
    let preserveFormatting: Bool
    
    init(
        messageText: String,
        targetLanguage: LanguageCode,
        sourceLanguage: LanguageCode? = nil,
        conversationId: String,
        messageId: String,
        preserveFormatting: Bool = true
    ) {
        self.messageText = messageText
        self.targetLanguage = targetLanguage
        self.sourceLanguage = sourceLanguage
        self.conversationId = conversationId
        self.messageId = messageId
        self.preserveFormatting = preserveFormatting
    }
}

/// Translation state for UI
enum TranslationState {
    case idle
    case translating
    case success(TranslationResult)
    case error(String)
    
    var isLoading: Bool {
        if case .translating = self {
            return true
        }
        return false
    }
    
    var translationResult: TranslationResult? {
        if case .success(let result) = self {
            return result
        }
        return nil
    }
    
    var errorMessage: String? {
        if case .error(let message) = self {
            return message
        }
        return nil
    }
}

/// User's preferred languages for translation
struct TranslationPreferences: Codable {
    var defaultTargetLanguage: LanguageCode
    var recentLanguages: [LanguageCode]
    var autoDetectSource: Bool
    var preserveFormatting: Bool
    var showConfidenceScores: Bool
    
    static let `default` = TranslationPreferences(
        defaultTargetLanguage: .english,
        recentLanguages: [],
        autoDetectSource: true,
        preserveFormatting: true,
        showConfidenceScores: false
    )
    
    /// Add a language to recent list (max 5)
    mutating func addRecentLanguage(_ language: LanguageCode) {
        // Remove if already exists
        recentLanguages.removeAll { $0 == language }
        
        // Add to front
        recentLanguages.insert(language, at: 0)
        
        // Keep only 5 most recent
        if recentLanguages.count > 5 {
            recentLanguages = Array(recentLanguages.prefix(5))
        }
    }
}

/// Cache for translations to avoid duplicate API calls
class TranslationCache {
    private var cache: [String: TranslationResult] = [:]
    private let maxCacheSize = 100
    private let cacheExpirationTime: TimeInterval = 24 * 60 * 60 // 24 hours
    
    /// Generate cache key
    private func cacheKey(text: String, targetLanguage: LanguageCode) -> String {
        return "\(text.prefix(100).lowercased())_\(targetLanguage.rawValue)"
    }
    
    /// Get cached translation if available and not expired
    func getTranslation(for text: String, targetLanguage: LanguageCode) -> TranslationResult? {
        let key = cacheKey(text: text, targetLanguage: targetLanguage)
        
        guard let cachedResult = cache[key] else {
            return nil
        }
        
        // Check if expired
        if Date().timeIntervalSince(cachedResult.timestamp) > cacheExpirationTime {
            cache.removeValue(forKey: key)
            return nil
        }
        
        return cachedResult
    }
    
    /// Cache a translation result
    func cacheTranslation(_ result: TranslationResult, for text: String) {
        let key = cacheKey(text: text, targetLanguage: result.targetLanguage)
        cache[key] = result
        
        // Clean up if cache gets too large
        if cache.count > maxCacheSize {
            cleanupCache()
        }
    }
    
    /// Remove expired entries and oldest entries if over limit
    private func cleanupCache() {
        let now = Date()
        
        // Remove expired entries
        cache = cache.filter { _, result in
            now.timeIntervalSince(result.timestamp) <= cacheExpirationTime
        }
        
        // If still over limit, remove oldest entries
        if cache.count > maxCacheSize {
            let sortedByDate = cache.sorted { $0.value.timestamp < $1.value.timestamp }
            let toKeep = sortedByDate.suffix(maxCacheSize - 10) // Keep 10 less than max
            
            cache = Dictionary(uniqueKeysWithValues: toKeep)
        }
    }
    
    /// Clear all cached translations
    func clearCache() {
        cache.removeAll()
    }
    
    /// Get cache statistics
    var cacheInfo: (count: Int, oldestEntry: Date?) {
        let oldestEntry = cache.values.min { $0.timestamp < $1.timestamp }?.timestamp
        return (cache.count, oldestEntry)
    }
}
