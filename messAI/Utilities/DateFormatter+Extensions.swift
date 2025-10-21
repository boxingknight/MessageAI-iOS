//
//  DateFormatter+Extensions.swift
//  messAI
//
//  Created by Isaac Jaramillo on 10/20/25.
//

import Foundation

// MARK: - Date Extensions

extension Date {
    /// Converts date to relative string: "2m ago", "5h ago", "Yesterday", "Mon"
    func relativeDateString() -> String {
        let calendar = Calendar.current
        let now = Date()
        
        let components = calendar.dateComponents(
            [.minute, .hour, .day, .weekOfYear],
            from: self,
            to: now
        )
        
        // Less than 1 minute: "Just now"
        if let minute = components.minute, minute < 1 {
            return "Just now"
        }
        
        // Less than 1 hour: "Xm ago"
        if let minute = components.minute,
           let hour = components.hour,
           hour < 1 {
            return "\(minute)m ago"
        }
        
        // Less than 24 hours: "Xh ago"
        if let hour = components.hour,
           let day = components.day,
           day < 1 {
            return "\(hour)h ago"
        }
        
        // Yesterday
        if calendar.isDateInYesterday(self) {
            return "Yesterday"
        }
        
        // Less than 1 week: "Mon", "Tue"
        if let week = components.weekOfYear, week < 1 {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE" // Mon, Tue, Wed
            return formatter.string(from: self)
        }
        
        // Older: "Dec 25"
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: self)
    }
    
    /// Format date as presence text: "Active now", "5m ago", "Last seen recently"
    func presenceText() -> String {
        let now = Date()
        let seconds = now.timeIntervalSince(self)
        
        switch seconds {
        case 0..<60:
            // Less than 1 minute
            return "Active now"
            
        case 60..<300:
            // 1-5 minutes
            let minutes = Int(seconds / 60)
            return "\(minutes)m ago"
            
        case 300..<3600:
            // 5-60 minutes
            return "Active recently"
            
        case 3600..<86400:
            // 1-24 hours
            return "Last seen today"
            
        default:
            // More than 24 hours
            return "Last seen recently"
        }
    }
}

// MARK: - DateFormatter Extensions

extension DateFormatter {
    /// Shared formatter for message timestamps
    static let messageTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short // 3:45 PM
        return formatter
    }()
    
    /// Shared formatter for full dates
    static let fullDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium // Dec 25, 2025
        formatter.timeStyle = .short
        return formatter
    }()
}

