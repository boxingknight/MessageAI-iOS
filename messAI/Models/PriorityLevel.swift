import Foundation
import SwiftUI

/**
 * PR#17: Priority Level for Message Highlighting
 * 
 * Represents the urgency/priority of a message as determined by AI analysis.
 * Used to visually highlight important messages with colored borders and badges.
 */

/// Priority level for messages (AI-detected urgency)
enum PriorityLevel: String, Codable, CaseIterable {
    case critical = "critical"  // Emergency, immediate action needed
    case high = "high"          // Important, timely action needed
    case normal = "normal"      // Regular conversation
    
    // MARK: - Display Properties
    
    /// Display name for UI
    var displayName: String {
        switch self {
        case .critical:
            return "Critical"
        case .high:
            return "High Priority"
        case .normal:
            return "Normal"
        }
    }
    
    /// Short display label
    var shortName: String {
        switch self {
        case .critical:
            return "Critical"
        case .high:
            return "High"
        case .normal:
            return "Normal"
        }
    }
    
    // MARK: - Visual Properties
    
    /// Border color for message bubble
    var borderColor: Color {
        switch self {
        case .critical:
            return .red
        case .high:
            return .orange
        case .normal:
            return .clear
        }
    }
    
    /// Background overlay color for message bubble
    var backgroundColor: Color {
        switch self {
        case .critical:
            return Color.red.opacity(0.05)
        case .high:
            return Color.orange.opacity(0.05)
        case .normal:
            return .clear
        }
    }
    
    /// Icon badge (SF Symbol)
    var icon: String {
        switch self {
        case .critical:
            return "exclamationmark.triangle.fill"
        case .high:
            return "exclamationmark.circle.fill"
        case .normal:
            return ""
        }
    }
    
    /// Icon color
    var iconColor: Color {
        switch self {
        case .critical:
            return .red
        case .high:
            return .orange
        case .normal:
            return .clear
        }
    }
    
    /// Text label color
    var textColor: Color {
        switch self {
        case .critical:
            return .red
        case .high:
            return .orange
        case .normal:
            return .primary
        }
    }
    
    /// Border width (points)
    var borderWidth: CGFloat {
        switch self {
        case .critical:
            return 2.0
        case .high:
            return 1.5
        case .normal:
            return 0
        }
    }
    
    // MARK: - Emoji Representation
    
    /// Emoji representation (for quick visual reference)
    var emoji: String {
        switch self {
        case .critical:
            return "🚨"
        case .high:
            return "⚠️"
        case .normal:
            return ""
        }
    }
    
    // MARK: - Priority Sorting
    
    /// Numeric priority for sorting (higher = more urgent)
    var sortOrder: Int {
        switch self {
        case .critical:
            return 3
        case .high:
            return 2
        case .normal:
            return 1
        }
    }
    
    // MARK: - Utility Methods
    
    /// Whether this priority level should be highlighted in UI
    var shouldHighlight: Bool {
        return self != .normal
    }
    
    /// Whether this message should appear in "Urgent Messages" view
    var isUrgent: Bool {
        return self == .critical || self == .high
    }
    
    /// Description for accessibility
    var accessibilityLabel: String {
        switch self {
        case .critical:
            return "Critical priority message. Requires immediate attention."
        case .high:
            return "High priority message. Requires timely attention."
        case .normal:
            return "Normal message."
        }
    }
}

// MARK: - Comparable for Sorting

extension PriorityLevel: Comparable {
    static func < (lhs: PriorityLevel, rhs: PriorityLevel) -> Bool {
        return lhs.sortOrder < rhs.sortOrder
    }
}

// MARK: - Priority Detection Result

/// Result from AI priority detection
struct PriorityDetectionResult: Codable, Equatable {
    let level: PriorityLevel
    let confidence: Double              // 0.0-1.0
    let method: DetectionMethod         // How it was detected
    let keywords: [String]?             // Keywords that triggered detection
    let reasoning: String               // Why this priority was assigned
    let processingTimeMs: Int           // How long detection took
    let usedGPT4: Bool                  // Whether GPT-4 was used
    
    enum DetectionMethod: String, Codable {
        case keyword = "keyword"        // Fast keyword filter only
        case gpt4 = "gpt4"             // GPT-4 analysis only
        case hybrid = "hybrid"         // Keyword + GPT-4 combined
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension PriorityLevel {
    /// Sample data for SwiftUI previews
    static let previewCritical = PriorityLevel.critical
    static let previewHigh = PriorityLevel.high
    static let previewNormal = PriorityLevel.normal
}

extension PriorityDetectionResult {
    /// Sample detection result for previews
    static let previewCritical = PriorityDetectionResult(
        level: .critical,
        confidence: 0.95,
        method: .hybrid,
        keywords: ["emergency", "now"],
        reasoning: "Emergency keyword detected with time-sensitive context",
        processingTimeMs: 2100,
        usedGPT4: true
    )
    
    static let previewHigh = PriorityDetectionResult(
        level: .high,
        confidence: 0.82,
        method: .hybrid,
        keywords: ["today", "pickup changed"],
        reasoning: "Time-sensitive schedule change for today",
        processingTimeMs: 1850,
        usedGPT4: true
    )
    
    static let previewNormal = PriorityDetectionResult(
        level: .normal,
        confidence: 0.88,
        method: .keyword,
        keywords: [],
        reasoning: "No urgency indicators detected",
        processingTimeMs: 45,
        usedGPT4: false
    )
}
#endif

