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
            print("🔍 [AIService] Raw event dict from Cloud Function:")
            print("  - title: \(eventDict["title"] ?? "nil")")
            print("  - date: \(eventDict["date"] ?? "nil")")
            print("  - time: \(eventDict["time"] ?? "nil")")
            print("  - isAllDay: \(eventDict["isAllDay"] ?? "nil")")
            print("  - confidence: \(eventDict["confidence"] ?? "nil")")
            
            let calendarEvent = CalendarEvent(from: eventDict)
            
            if let event = calendarEvent {
                print("✅ [AIService] Successfully parsed CalendarEvent:")
                print("   - title: \(event.title)")
                print("   - date: \(event.date)")
                print("   - time: \(event.time?.description ?? "nil")")
                print("   - isAllDay: \(event.isAllDay)")
            } else {
                print("❌ [AIService] Failed to parse CalendarEvent from dict")
            }
            
            return calendarEvent
        }
        
        print("✅ AIService: Extracted \(calendarEvents.count) calendar events")
        
        return calendarEvents
    }
    
    // MARK: - Decision Summarization (PR #16)
    
    /// Summarize conversation decisions and action items
    /// Returns ConversationSummary with decisions, action items, and key points
    func summarizeConversation(conversationId: String) async throws -> ConversationSummary {
        print("📝 AIService: Summarizing conversation \(conversationId)")
        
        // Check cache (conversation-specific)
        let cacheKey = "summary:\(conversationId)"
        if let cached = cache[cacheKey],
           Date().timeIntervalSince(cached.timestamp) < cacheExpiration {
            print("✅ AIService: Using cached summary (age: \(Int(Date().timeIntervalSince(cached.timestamp)))s)")
            if let summary = cached.result as? ConversationSummary {
                return summary
            }
        }
        
        // Prepare request data
        let data: [String: Any] = [
            "feature": AIFeature.decision.rawValue,
            "conversationId": conversationId
        ]
        
        print("📤 AIService: Calling Cloud Function for decision summarization")
        
        // Call Cloud Function
        let callable = functions.httpsCallable("processAI")
        
        do {
            let result = try await callable.call(data)
            
            guard let resultData = result.data as? [String: Any] else {
                print("❌ AIService: Invalid response format")
                throw AIError.invalidResponse
            }
            
            // Check if summary was generated
            guard let hasSummary = resultData["hasSummary"] as? Bool, hasSummary else {
                // Not enough messages or other reason
                let message = resultData["message"] as? String ?? "Unable to generate summary"
                print("⚠️ AIService: \(message)")
                throw AIError.serverError(message)
            }
            
            // Parse summary dictionary
            guard let summaryDict = resultData["summary"] as? [String: Any] else {
                print("❌ AIService: Missing summary data in response")
                throw AIError.invalidResponse
            }
            
            // Convert to ConversationSummary model
            guard let summary = ConversationSummary(dictionary: summaryDict) else {
                print("❌ AIService: Failed to parse ConversationSummary from response")
                print("   Response: \(summaryDict)")
                throw AIError.invalidResponse
            }
            
            print("✅ AIService: Summary generated successfully")
            print("   - Decisions: \(summary.decisions.count)")
            print("   - Action Items: \(summary.actionItems.count)")
            print("   - Key Points: \(summary.keyPoints.count)")
            print("   - Messages Analyzed: \(summary.messageCount)")
            
            // Cache result (as ConversationSummary object)
            cache[cacheKey] = (summary, Date())
            
            return summary
            
        } catch let error as NSError {
            print("❌ AIService: Error calling Cloud Function: \(error)")
            throw mapFirebaseError(error)
        }
    }
}

