//
//  MessageStatus.swift
//  messAI
//
//  Created by Isaac Jaramillo on 10/20/25.
//

import SwiftUI

/// Represents the delivery status of a message
enum MessageStatus: String, Codable, CaseIterable {
    case sending = "sending"   // Local only, not sent to server yet
    case sent = "sent"         // Successfully sent to Firestore
    case delivered = "delivered" // Delivered to recipient's device
    case read = "read"         // Recipient opened/read the message
    case failed = "failed"     // Failed to send (will retry)
    
    /// User-friendly display text for each status
    var displayText: String {
        switch self {
        case .sending: return "Sending..."
        case .sent: return "Sent"
        case .delivered: return "Delivered"
        case .read: return "Read"
        case .failed: return "Failed"
        }
    }
    
    /// SF Symbol icon name for each status
    var iconName: String {
        switch self {
        case .sending: return "clock"
        case .sent: return "checkmark"
        case .delivered: return "checkmark.circle"
        case .read: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.circle"
        }
    }
    
    /// Color for each status
    var color: Color {
        switch self {
        case .sending: return .gray
        case .sent: return .gray
        case .delivered: return .blue
        case .read: return .blue
        case .failed: return .red
        }
    }
}

