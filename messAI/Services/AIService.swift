import Foundation
import FirebaseFunctions

/// AI features available through Cloud Functions
enum AIFeature: String, Codable {
    case calendar
    case decision
    case urgency
    case rsvp
    case deadline
    case agent
}

/// Errors that can occur during AI processing
enum AIError: LocalizedError {
    case unauthenticated
    case rateLimitExceeded
    case invalidResponse
    case networkError
    case serverError(String)
    case unknownFeature
    
    var errorDescription: String? {
        switch self {
        case .unauthenticated:
            return "You must be logged in to use AI features."
        case .rateLimitExceeded:
            return "Too many AI requests. Please try again in an hour."
        case .invalidResponse:
            return "Received invalid response from AI service."
        case .networkError:
            return "Network error. Please check your connection."
        case .serverError(let message):
            return "Server error: \(message)"
        case .unknownFeature:
            return "Unknown AI feature requested."
        }
    }
}

/// Service for calling AI Cloud Functions
@MainActor
class AIService {
    static let shared = AIService()
    private let functions = Functions.functions()
    
    // Cache for AI results (5 minutes)
    private var cache: [String: (result: Any, timestamp: Date)] = [:]
    private let cacheExpiration: TimeInterval = 300 // 5 minutes
    
    private init() {}
    
    /// Process a message with specified AI feature
    func processMessage(
        _ message: String,
        feature: AIFeature,
        context: [Message]? = nil,
        conversationId: String? = nil
    ) async throws -> [String: Any] {
        
        // Check cache
        let cacheKey = "\(feature.rawValue):\(message.prefix(100))"
        if let cached = cache[cacheKey],
           Date().timeIntervalSince(cached.timestamp) < cacheExpiration {
            print("✅ AIService: Cache hit for \(feature.rawValue)")
            return cached.result as! [String: Any]
        }
        
        // Prepare request data
        var data: [String: Any] = [
            "feature": feature.rawValue,
            "message": message
        ]
        
        if let context = context {
            data["context"] = context.map { [
                "text": $0.text,
                "senderId": $0.senderId,
                "sentAt": $0.sentAt.timeIntervalSince1970
            ]}
        }
        
        if let conversationId = conversationId {
            data["conversationId"] = conversationId
        }
        
        print("📤 AIService: Calling Cloud Function for \(feature.rawValue)")
        
        // Call Cloud Function
        let callable = functions.httpsCallable("processAI")
        
        do {
            let result = try await callable.call(data)
            
            guard let resultData = result.data as? [String: Any] else {
                throw AIError.invalidResponse
            }
            
            print("✅ AIService: Received response from \(feature.rawValue)")
            
            // Cache result
            cache[cacheKey] = (resultData, Date())
            
            return resultData
            
        } catch let error as NSError {
            print("❌ AIService: Error calling Cloud Function: \(error)")
            throw mapFirebaseError(error)
        }
    }
    
    /// Map Firebase errors to AIError
    private func mapFirebaseError(_ error: NSError) -> AIError {
        switch error.code {
        case FunctionsErrorCode.unauthenticated.rawValue:
            return .unauthenticated
        case FunctionsErrorCode.resourceExhausted.rawValue:
            return .rateLimitExceeded
        case FunctionsErrorCode.unavailable.rawValue:
            return .networkError
        case FunctionsErrorCode.invalidArgument.rawValue:
            return .serverError(error.localizedDescription)
        default:
            return .serverError(error.localizedDescription)
        }
    }
    
    /// Clear cache (useful for testing)
    func clearCache() {
        cache.removeAll()
        print("🗑️ AIService: Cache cleared")
    }
    
    // MARK: - Calendar Extraction (PR #15)
    
    /// Extract calendar events from a message
    /// Returns structured CalendarEvent objects ready for display
    func extractCalendarEvents(from message: String) async throws -> [CalendarEvent] {
        print("📅 AIService: Extracting calendar events from message")
        
        let result = try await processMessage(message, feature: .calendar)
        
        // Parse events array from response
        guard let eventsArray = result["events"] as? [[String: Any]] else {
            print("⚠️ AIService: No events array in response")
            return []
        }
        
        // Convert each event dictionary to CalendarEvent
        let calendarEvents = eventsArray.compactMap { eventDict -> CalendarEvent? in
            return CalendarEvent(from: eventDict)
        }
        
        print("✅ AIService: Extracted \(calendarEvents.count) calendar events")
        
        return calendarEvents
    }
}

