import Foundation
import FirebaseFunctions
import FirebaseFirestore

/// AI features available through Cloud Functions
enum AIFeature: String, Codable {
    case calendar
    case decision
    case urgency
    case priority   // PR#17: Priority Highlighting
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
    
    // MARK: - Priority Highlighting (PR #17)
    
    /// Detect priority level of a message using hybrid AI approach
    /// Returns PriorityDetectionResult with level, confidence, and reasoning
    func detectPriority(
        messageText: String,
        conversationId: String
    ) async throws -> PriorityDetectionResult {
        print("🎯 AIService: Detecting priority for message in conversation \(conversationId)")
        
        // Prepare request data
        let data: [String: Any] = [
            "feature": AIFeature.priority.rawValue,
            "messageText": messageText,
            "conversationId": conversationId
        ]
        
        print("📤 AIService: Calling Cloud Function for priority detection")
        
        // Call Cloud Function
        let callable = functions.httpsCallable("processAI")
        
        do {
            let result = try await callable.call(data)
            
            guard let resultData = result.data as? [String: Any] else {
                print("❌ AIService: Invalid response format")
                throw AIError.invalidResponse
            }
            
            // Parse priority detection result
            guard let levelString = resultData["level"] as? String,
                  let level = PriorityLevel(rawValue: levelString),
                  let confidence = resultData["confidence"] as? Double,
                  let methodString = resultData["method"] as? String,
                  let method = PriorityDetectionResult.DetectionMethod(rawValue: methodString),
                  let reasoning = resultData["reasoning"] as? String,
                  let processingTimeMs = resultData["processingTimeMs"] as? Int,
                  let usedGPT4 = resultData["usedGPT4"] as? Bool else {
                print("❌ AIService: Failed to parse priority detection response")
                print("   Response: \(resultData)")
                throw AIError.invalidResponse
            }
            
            // Parse optional keywords array
            let keywords = resultData["keywords"] as? [String]
            
            let priorityResult = PriorityDetectionResult(
                level: level,
                confidence: confidence,
                method: method,
                keywords: keywords,
                reasoning: reasoning,
                processingTimeMs: processingTimeMs,
                usedGPT4: usedGPT4
            )
            
            // print("✅ AIService: Priority detected successfully")
            // print("   - Level: \(level.rawValue)")
            // print("   - Confidence: \(String(format: "%.2f", confidence))")
            // print("   - Method: \(method.rawValue)")
            // print("   - Used GPT-4: \(usedGPT4)")
            // print("   - Processing Time: \(processingTimeMs)ms")
            
            return priorityResult
            
        } catch let error as NSError {
            print("❌ AIService: Error calling Cloud Function: \(error)")
            throw mapFirebaseError(error)
        }
    }
    
    // MARK: - RSVP Tracking (PR #18)
    
    /// Track RSVP responses in messages using hybrid AI approach
    /// Returns RSVPResponse with status (yes/no/maybe), confidence, and linked event
    func trackRSVP(
        messageText: String,
        messageId: String,
        senderId: String,
        senderName: String,
        conversationId: String,
        recentEventIds: [String]? = nil
    ) async throws -> RSVPResponse? {
        print("🎯 AIService: Tracking RSVP for message in conversation \(conversationId)")
        
        // Prepare request data
        var data: [String: Any] = [
            "feature": AIFeature.rsvp.rawValue,
            "messageText": messageText,
            "messageId": messageId,
            "senderId": senderId,
            "senderName": senderName,
            "conversationId": conversationId
        ]
        
        // Add recent event IDs if provided
        if let recentEventIds = recentEventIds, !recentEventIds.isEmpty {
            data["recentEventIds"] = recentEventIds
        }
        
        print("📤 AIService: Calling Cloud Function for RSVP tracking")
        
        // Call Cloud Function
        let callable = functions.httpsCallable("processAI")
        
        do {
            let result = try await callable.call(data)
            
            guard let resultData = result.data as? [String: Any] else {
                print("❌ AIService: Invalid response format")
                throw AIError.invalidResponse
            }
            
            // Check if RSVP was detected
            guard let detected = resultData["detected"] as? Bool else {
                print("❌ AIService: Missing 'detected' field in response")
                throw AIError.invalidResponse
            }
            
            // If no RSVP detected, return nil
            if !detected {
                print("✅ AIService: No RSVP detected in message")
                return nil
            }
            
            // Parse RSVP response
            guard let statusString = resultData["status"] as? String,
                  let status = RSVPStatus(rawValue: statusString),
                  let confidence = resultData["confidence"] as? Double,
                  let methodString = resultData["method"] as? String,
                  let method = RSVPResponse.DetectionMethod(rawValue: methodString) else {
                print("❌ AIService: Failed to parse RSVP response")
                print("   Response: \(resultData)")
                throw AIError.invalidResponse
            }
            
            // Parse optional fields
            let eventId = resultData["eventId"] as? String
            let reasoning = resultData["reasoning"] as? String
            
            let rsvpResponse = RSVPResponse(
                status: status,
                eventId: eventId,
                confidence: confidence,
                reasoning: reasoning,
                detectedAt: Date(),
                method: method
            )
            
            print("✅ AIService: RSVP detected successfully")
            print("   - Status: \(status.rawValue)")
            print("   - Confidence: \(String(format: "%.2f", confidence))")
            print("   - Event ID: \(eventId ?? "none")")
            print("   - Method: \(method.rawValue)")
            
            return rsvpResponse
            
        } catch let error as NSError {
            print("❌ AIService: Error calling Cloud Function: \(error)")
            throw mapFirebaseError(error)
        }
    }
    
    // MARK: - PR#19: Deadline Extraction
    
    /**
     * Extract deadline from message text
     * Uses hybrid approach: keyword filter → GPT-4 extraction
     * Returns structured deadline data or nil if no deadline detected
     * 
     * Example:
     * ```
     * let deadline = try await aiService.extractDeadline(
     *     messageText: "Please RSVP by Friday at 5pm",
     *     messageId: "msg123",
     *     senderId: "user123",
     *     senderName: "Alice",
     *     conversationId: "conv456"
     * )
     * ```
     */
    func extractDeadline(
        messageText: String,
        messageId: String,
        senderId: String,
        senderName: String,
        conversationId: String,
        storeInFirestore: Bool = true
    ) async throws -> DeadlineDetection? {
        print("🚨 DEADLINE: AIService calling Cloud Function...")
        
        // BUG FIX (PR#19.1): Pass timezone and current timestamp to fix date parsing issues
        let currentTimestamp = Date().timeIntervalSince1970
        // TEMP FIX: Force Central timezone for testing
        let userTimezone = "America/Chicago"  // Central Time (CST/CDT)
        // let userTimezone = TimeZone.current.identifier  // TODO: Re-enable for production
        
        // Prepare request data
        let data: [String: Any] = [
            "feature": AIFeature.deadline.rawValue,
            "conversationId": conversationId,
            "messageId": messageId,
            "messageText": messageText,
            "senderId": senderId,
            "senderName": senderName,
            "currentTimestamp": currentTimestamp,
            "userTimezone": userTimezone,
            "storeInFirestore": storeInFirestore
        ]
        
        print("📤 AIService: Calling Cloud Function for deadline extraction")
        print("   Message: \(messageText.prefix(50))...")
        
        // Call Cloud Function
        let callable = functions.httpsCallable("processAI")
        
        do {
            let result = try await callable.call(data)
            
            guard let resultData = result.data as? [String: Any] else {
                print("🚨 DEADLINE: ❌ result.data is not a dictionary!")
                print("🚨 DEADLINE:    Type: \(type(of: result.data))")
                print("🚨 DEADLINE:    Value: \(result.data)")
                throw AIError.invalidResponse
            }
            
            print("🚨 DEADLINE: 📦 Raw response from Cloud Function:")
            print("🚨 DEADLINE:    Keys: \(resultData.keys.sorted())")
            print("🚨 DEADLINE:    Full data: \(resultData)")
            
            // Check if deadline was detected
            guard let detected = resultData["detected"] as? Bool else {
                print("🚨 DEADLINE: ❌ 'detected' field is missing or not a Bool!")
                print("🚨 DEADLINE:    detected value: \(resultData["detected"] ?? "missing")")
                print("🚨 DEADLINE:    detected type: \(type(of: resultData["detected"]))")
                throw AIError.invalidResponse
            }
            
            // If no deadline detected, return nil
            if !detected {
                print("🚨 DEADLINE: ℹ️ Cloud Function returned: No deadline detected")
                return nil
            }
            
            // Parse deadline data
            guard let deadlineData = resultData["deadline"] as? [String: Any],
                  let title = deadlineData["title"] as? String,
                  let dueDateString = deadlineData["dueDate"] as? String,
                  let isAllDay = deadlineData["isAllDay"] as? Bool,
                  let priorityString = deadlineData["priority"] as? String,
                  let confidence = resultData["confidence"] as? Double,
                  let methodString = resultData["method"] as? String else {
                print("❌ AIService: Failed to parse deadline response")
                print("   Response: \(resultData)")
                throw AIError.invalidResponse
            }
            
            // Parse optional fields BEFORE date parsing (for fallback case)
            let deadlineId = resultData["deadlineId"] as? String
            let reasoning = resultData["reasoning"] as? String
            
            // Parse due date
            // BUG FIX (PR#19.1): Add .withFractionalSeconds to parse "2025-10-24T17:00:00.000Z"
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            guard let dueDate = dateFormatter.date(from: dueDateString) else {
                print("🚨 DEADLINE: ❌ Failed to parse due date: \(dueDateString)")
                print("🚨 DEADLINE:    Trying fallback parser without fractional seconds...")
                
                // Fallback: try without fractional seconds
                let fallbackFormatter = ISO8601DateFormatter()
                fallbackFormatter.formatOptions = [.withInternetDateTime]
                guard let fallbackDate = fallbackFormatter.date(from: dueDateString) else {
                    print("🚨 DEADLINE: ❌ Fallback parser also failed!")
                    throw AIError.invalidResponse
                }
                
                print("🚨 DEADLINE: ✅ Fallback parser succeeded")
                return DeadlineDetection(
                    deadlineId: deadlineId,
                    title: title,
                    dueDate: fallbackDate,
                    isAllDay: isAllDay,
                    priority: priorityString,
                    confidence: confidence,
                    method: methodString,
                    reasoning: reasoning
                )
            }
            
            let deadlineDetection = DeadlineDetection(
                deadlineId: deadlineId,
                title: title,
                dueDate: dueDate,
                isAllDay: isAllDay,
                priority: priorityString,
                confidence: confidence,
                method: methodString,
                reasoning: reasoning
            )
            
            print("🚨 DEADLINE: ✅ Cloud Function SUCCESS!")
            print("🚨 DEADLINE:    - Title: \(title)")
            print("🚨 DEADLINE:    - Due: \(dueDate)")
            print("🚨 DEADLINE:    - Priority: \(priorityString)")
            print("🚨 DEADLINE:    - Confidence: \(String(format: "%.2f", confidence))")
            print("🚨 DEADLINE:    - Method: \(methodString)")
            if let deadlineId = deadlineId {
                print("🚨 DEADLINE:    - Stored with ID: \(deadlineId)")
            }
            
            return deadlineDetection
            
        } catch let error as NSError {
            print("🚨 DEADLINE: ❌ Cloud Function ERROR: \(error)")
            throw mapFirebaseError(error)
        }
    }
    
    /**
     * Fetch deadlines for a conversation from Firestore
     * Returns all active deadlines sorted by due date
     */
    func fetchDeadlines(conversationId: String) async throws -> [Deadline] {
        print("🎯 AIService: Fetching deadlines for conversation: \(conversationId)")
        
        let db = Firestore.firestore()
        let deadlinesRef = db.collection("conversations")
            .document(conversationId)
            .collection("deadlines")
        
        // Query active deadlines, ordered by due date
        let snapshot = try await deadlinesRef
            .whereField("status", isEqualTo: "active")
            .order(by: "dueDate", descending: false)
            .getDocuments()
        
        let deadlines = snapshot.documents.compactMap { doc in
            Deadline.fromFirestore(doc.data(), id: doc.documentID)
        }
        
        print("✅ AIService: Fetched \(deadlines.count) deadlines")
        return deadlines
    }
    
    /**
     * Mark deadline as completed
     */
    func completeDeadline(conversationId: String, deadlineId: String, userId: String) async throws {
        print("🎯 AIService: Completing deadline: \(deadlineId)")
        
        let db = Firestore.firestore()
        let deadlineRef = db.collection("conversations")
            .document(conversationId)
            .collection("deadlines")
            .document(deadlineId)
        
        try await deadlineRef.updateData([
            "status": "completed",
            "completedAt": Date(),
            "completedBy": userId,
            "updatedAt": Date()
        ])
        
        print("✅ AIService: Deadline marked as completed")
    }
}

