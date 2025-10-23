//
//  Opportunity.swift
//  messAI
//
//  PR#20.1: Proactive AI Agent - iOS Models
//  Mirrors the Cloud Function TypeScript interfaces
//

import Foundation

// MARK: - Opportunity Type

enum OpportunityType: String, Codable {
    case eventPlanning = "event_planning"
    case priorityDetection = "priority_detection"
    case deadlineTracking = "deadline_tracking"
    case rsvpManagement = "rsvp_management"
    case decisionSummary = "decision_summary"
    
    var displayName: String {
        switch self {
        case .eventPlanning: return "Event Planning"
        case .priorityDetection: return "Priority Item"
        case .deadlineTracking: return "Deadline"
        case .rsvpManagement: return "RSVP Tracking"
        case .decisionSummary: return "Decision"
        }
    }
    
    var icon: String {
        switch self {
        case .eventPlanning: return "calendar.badge.plus"
        case .priorityDetection: return "exclamationmark.triangle.fill"
        case .deadlineTracking: return "clock.badge.exclamationmark"
        case .rsvpManagement: return "checkmark.circle"
        case .decisionSummary: return "checkmark.seal.fill"
        }
    }
}

// MARK: - Opportunity

struct Opportunity: Identifiable, Codable {
    let id: String
    let type: OpportunityType
    let confidence: Double // 0.0-1.0
    let data: OpportunityData
    let suggestedActions: [String]
    let reasoning: String
    let timestamp: Date
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Generate ID from type + timestamp if not provided
        if let id = try? container.decode(String.self, forKey: .id) {
            self.id = id
        } else {
            self.id = UUID().uuidString
        }
        
        self.type = try container.decode(OpportunityType.self, forKey: .type)
        self.confidence = try container.decode(Double.self, forKey: .confidence)
        self.data = try container.decode(OpportunityData.self, forKey: .data)
        self.suggestedActions = try container.decode([String].self, forKey: .suggestedActions)
        self.reasoning = try container.decode(String.self, forKey: .reasoning)
        
        // Handle timestamp (might come as Firestore Timestamp or ISO8601 string)
        if let timestamp = try? container.decode(Date.self, forKey: .timestamp) {
            self.timestamp = timestamp
        } else {
            self.timestamp = Date()
        }
    }
    
    // Confidence levels
    var isHighConfidence: Bool { confidence > 0.8 }
    var isMediumConfidence: Bool { confidence > 0.6 && confidence <= 0.8 }
    var isLowConfidence: Bool { confidence > 0.5 && confidence <= 0.6 }
    
    // Display helpers
    var confidencePercentage: Int {
        Int(confidence * 100)
    }
    
    var displayTitle: String {
        switch type {
        case .eventPlanning:
            return data.title ?? "Event Planning Opportunity"
        case .priorityDetection:
            return "Urgent: \(data.priorityLevel?.rawValue.capitalized ?? "Priority")"
        case .deadlineTracking:
            return data.task ?? "Deadline"
        case .rsvpManagement:
            return "RSVP Needed"
        case .decisionSummary:
            return "Decision Made"
        }
    }
}

// MARK: - Opportunity Data

struct OpportunityData: Codable {
    // Event Planning
    var title: String?
    var eventType: String?
    var date: String?
    var time: String?
    var location: String?
    var participants: [String]?
    var notes: String?
    
    // Priority Detection
    var priorityLevel: PriorityLevel?
    var urgentReason: String?
    
    // Deadline Tracking
    var deadline: String?
    var task: String?
    
    // RSVP Management
    var eventReference: String?
    var needsRSVP: Bool?
    
    // Decision Summary
    var decision: String?
    var decisionParticipants: [String]?
    var agreedActions: [String]?
    
    enum PriorityLevel: String, Codable {
        case critical
        case high
        case normal
    }
}

// MARK: - Detection Response

struct DetectionResponse: Codable {
    let opportunities: [Opportunity]
    let tokensUsed: Int
    let cost: Double
    let cached: Bool
    let timestamp: Date
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.opportunities = try container.decode([Opportunity].self, forKey: .opportunities)
        self.tokensUsed = try container.decode(Int.self, forKey: .tokensUsed)
        self.cost = try container.decode(Double.self, forKey: .cost)
        self.cached = try container.decode(Bool.self, forKey: .cached)
        
        // Handle timestamp
        if let timestamp = try? container.decode(Date.self, forKey: .timestamp) {
            self.timestamp = timestamp
        } else if let timestampString = try? container.decode(String.self, forKey: .timestamp) {
            let formatter = ISO8601DateFormatter()
            self.timestamp = formatter.date(from: timestampString) ?? Date()
        } else {
            self.timestamp = Date()
        }
    }
}

// MARK: - Coding Keys

extension Opportunity {
    enum CodingKeys: String, CodingKey {
        case id, type, confidence, data, suggestedActions, reasoning, timestamp
    }
}

extension DetectionResponse {
    enum CodingKeys: String, CodingKey {
        case opportunities, tokensUsed, cost, cached, timestamp
    }
}

