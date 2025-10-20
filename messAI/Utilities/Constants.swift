//
//  Constants.swift
//  messAI
//
//  Created by Isaac Jaramillo on 10/20/25.
//

import Foundation
import SwiftUI

/// App-wide constants for configuration and styling
struct Constants {
    
    // MARK: - App Configuration
    
    /// App display name
    static let appName = "MessageAI"
    
    /// App version
    static let appVersion = "1.0.0"
    
    /// Minimum iOS version supported
    static let minimumIOSVersion = "16.0"
    
    // MARK: - Firebase Configuration
    
    /// Firestore collection names
    struct Firestore {
        static let users = "users"
        static let conversations = "conversations"
        static let messages = "messages"
        static let presence = "presence"
        static let typingStatus = "typingStatus"
    }
    
    /// Firebase Storage paths
    struct Storage {
        static let profilePictures = "profile_pictures"
        static let chatImages = "chat_images"
    }
    
    // MARK: - UI Constants
    
    /// Message limits
    struct Messages {
        static let maxTextLength = 10_000
        static let messageFetchLimit = 50
    }
    
    /// Image constraints
    struct Images {
        static let maxImageSizeMB: Double = 2.0
        static let maxImageWidth: CGFloat = 1920
        static let thumbnailSize = CGSize(width: 200, height: 200)
        static let profileImageSize = CGSize(width: 200, height: 200)
    }
    
    /// Timing
    struct Timing {
        static let typingIndicatorTimeout: TimeInterval = 3.0
        static let typingDebounceDelay: TimeInterval = 0.5
        static let messageRetryDelay: TimeInterval = 2.0
    }
    
    // MARK: - Colors
    
    struct Colors {
        static let primary = Color.blue
        static let accent = Color.green
        static let sentMessage = Color.blue
        static let receivedMessage = Color.gray.opacity(0.2)
        static let onlineIndicator = Color.green
        static let offlineIndicator = Color.gray
    }
    
    // MARK: - Spacing
    
    struct Spacing {
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let extraLarge: CGFloat = 32
    }
}

