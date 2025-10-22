//
//  ActionItem.swift
//  messAI
//
//  Created for PR #16: Decision Summarization Feature
//  Action item extracted from conversation summary
//

import Foundation

/**
 * Action item from conversation summary
 *
 * Represents a task or action that needs to be completed,
 * optionally with an assignee and deadline.
 *
 * Example: "Sarah: Bring cookies by Friday"
 */
struct ActionItem: Identifiable, Codable, Equatable, Hashable {
    // MARK: - Properties
    
    /// Unique identifier
    let id: String
    
    /// What needs to be done
    let description: String
    
    /// Who is responsible (if mentioned)
    let assignee: String?
    
    /// When it's due (if mentioned)
    let deadline: String?
    
    // MARK: - Initialization
    
    init(
        id: String,
        description: String,
        assignee: String? = nil,
        deadline: String? = nil
    ) {
        self.id = id
        self.description = description
        self.assignee = assignee
        self.deadline = deadline
    }
    
    // MARK: - Firestore Conversion
    
    /// Convert from Firestore dictionary
    init?(dictionary: [String: Any]) {
        guard let id = dictionary["id"] as? String,
              let description = dictionary["description"] as? String else {
            return nil
        }
        
        self.id = id
        self.description = description
        self.assignee = dictionary["assignee"] as? String
        self.deadline = dictionary["deadline"] as? String
    }
    
    /// Convert to Firestore dictionary
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "description": description
        ]
        
        if let assignee = assignee {
            dict["assignee"] = assignee
        }
        
        if let deadline = deadline {
            dict["deadline"] = deadline
        }
        
        return dict
    }
    
    // MARK: - Display Helpers
    
    /// Formatted display text
    /// Examples:
    /// - "Bring cookies" (no assignee, no deadline)
    /// - "Sarah: Bring cookies" (with assignee)
    /// - "Bring cookies by Friday" (with deadline)
    /// - "Sarah: Bring cookies by Friday" (both)
    var displayText: String {
        var text = ""
        
        // Add assignee if present
        if let assignee = assignee {
            text += "\(assignee): "
        }
        
        // Add description
        text += description
        
        // Add deadline if present
        if let deadline = deadline {
            text += " by \(deadline)"
        }
        
        return text
    }
    
    /// Short description (no assignee/deadline)
    var shortDescription: String {
        return description
    }
    
    /// Has assignee?
    var hasAssignee: Bool {
        return assignee != nil && !assignee!.isEmpty
    }
    
    /// Has deadline?
    var hasDeadline: Bool {
        return deadline != nil && !deadline!.isEmpty
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension ActionItem {
    /// Sample action items for SwiftUI previews
    static let sample1 = ActionItem(
        id: "action_1",
        description: "Bring cookies",
        assignee: "Sarah",
        deadline: "Friday"
    )
    
    static let sample2 = ActionItem(
        id: "action_2",
        description: "Set up tables",
        assignee: "Mike",
        deadline: nil
    )
    
    static let sample3 = ActionItem(
        id: "action_3",
        description: "Send invitations",
        assignee: nil,
        deadline: "Wednesday"
    )
    
    static let sample4 = ActionItem(
        id: "action_4",
        description: "Book venue",
        assignee: nil,
        deadline: nil
    )
    
    static let samples: [ActionItem] = [sample1, sample2, sample3, sample4]
}
#endif

