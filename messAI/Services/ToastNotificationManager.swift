//
//  ToastNotificationManager.swift
//  messAI
//
//  Created for PR#17.1: In-App Toast Notifications
//

import Foundation
import Combine
import SwiftUI

/// Manages in-app toast notifications
/// Singleton service that handles toast display, queue management, and user interactions
@MainActor
class ToastNotificationManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = ToastNotificationManager()
    
    private init() {}
    
    // MARK: - Published Properties
    
    /// The currently displayed toast (nil if none)
    @Published var currentToast: ToastMessage?
    
    /// Whether a toast is currently being displayed
    @Published var isShowingToast: Bool = false
    
    // MARK: - Internal State
    
    /// ID of the conversation currently being viewed by the user
    /// Toast won't show for messages in this conversation
    var activeConversationId: String?
    
    /// Queue of pending toasts waiting to be displayed
    private var toastQueue: [ToastMessage] = []
    
    /// Maximum number of toasts in queue (prevents memory issues)
    private let maxQueueSize = 5
    
    /// Duration to show each toast (in seconds)
    private let toastDuration: Double = 4.0
    
    /// Task for auto-dismiss timer
    private var dismissTask: Task<Void, Never>?
    
    // MARK: - Public Methods
    
    /// Show a toast notification (or queue it if one is already showing)
    /// - Parameter toast: The toast to display
    func showToast(_ toast: ToastMessage) {
        print("🔔 Toast request: \(toast.senderName) - \(toast.displayText)")
        
        // Check if we should show this toast
        guard shouldShowToast(conversationId: toast.conversationId) else {
            print("   ❌ Skipped: User is in this conversation")
            return
        }
        
        // If already showing a toast, queue this one
        if isShowingToast {
            queueToast(toast)
            return
        }
        
        // Display immediately
        displayToast(toast)
    }
    
    /// Check if a toast should be shown for a given conversation
    /// - Parameter conversationId: The conversation ID to check
    /// - Returns: True if toast should be shown, false otherwise
    func shouldShowToast(conversationId: String) -> Bool {
        // No active conversation (on chat list) → SHOW toast
        guard let activeId = activeConversationId else {
            print("   ✅ No active conversation (on chat list) → SHOW toast")
            return true
        }
        
        // Don't show if message is for the active conversation
        let shouldShow = conversationId != activeId
        print("   🤔 Should show? Active: \(activeId), Message: \(conversationId) → \(shouldShow)")
        return shouldShow
    }
    
    /// Dismiss the currently displayed toast
    func dismissToast() {
        print("   ⬆️ Dismissing toast")
        
        // Cancel auto-dismiss timer
        dismissTask?.cancel()
        dismissTask = nil
        
        // Hide toast with animation
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isShowingToast = false
            currentToast = nil
        }
        
        // Process next toast in queue after animation completes
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s for animation
            processQueue()
        }
    }
    
    /// Handle tap on toast - navigate to conversation
    /// - Parameter conversationId: ID of conversation to open
    func handleToastTap(conversationId: String) {
        print("   👆 Toast tapped: Navigate to \(conversationId)")
        
        // Dismiss toast immediately
        dismissTask?.cancel()
        dismissTask = nil
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            isShowingToast = false
            currentToast = nil
        }
        
        // Post notification for navigation
        NotificationCenter.default.post(
            name: NSNotification.Name("OpenConversationFromToast"),
            object: nil,
            userInfo: ["conversationId": conversationId]
        )
    }
    
    // MARK: - Private Methods
    
    /// Display a toast with animation and auto-dismiss
    /// - Parameter toast: The toast to display
    private func displayToast(_ toast: ToastMessage) {
        print("   ✅ Displaying toast: \(toast.senderName)")
        
        // Set current toast
        currentToast = toast
        
        // Show with animation
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isShowingToast = true
        }
        
        // Set up auto-dismiss timer
        dismissTask = Task {
            print("   ⏱️ Starting 4-second timer")
            try? await Task.sleep(nanoseconds: UInt64(toastDuration * 1_000_000_000))
            
            // Check if task was cancelled
            if !Task.isCancelled {
                print("   ⏰ Timer complete, auto-dismissing")
                dismissToast()
            }
        }
    }
    
    /// Add a toast to the queue
    /// - Parameter toast: The toast to queue
    private func queueToast(_ toast: ToastMessage) {
        // Check queue size
        if toastQueue.count >= maxQueueSize {
            print("   📬 Queue full (\(maxQueueSize)), dropping oldest")
            toastQueue.removeFirst() // Drop oldest
        }
        
        toastQueue.append(toast)
        print("   📬 Toast queued. Queue size: \(toastQueue.count)")
    }
    
    /// Process the next toast in queue
    private func processQueue() {
        guard !isShowingToast else {
            print("   ⏸️ Still showing toast, will process queue later")
            return
        }
        
        guard !toastQueue.isEmpty else {
            print("   📭 Queue empty")
            return
        }
        
        // Get next toast
        let nextToast = toastQueue.removeFirst()
        print("   📤 Processing queued toast: \(nextToast.senderName)")
        print("   📊 Remaining in queue: \(toastQueue.count)")
        
        // Display it
        displayToast(nextToast)
    }
    
    // MARK: - Debug Methods
    
    #if DEBUG
    /// Reset manager state (for testing)
    func reset() {
        dismissTask?.cancel()
        dismissTask = nil
        currentToast = nil
        isShowingToast = false
        toastQueue.removeAll()
        activeConversationId = nil
        print("🔄 ToastNotificationManager reset")
    }
    
    /// Get current queue size (for testing)
    var queueSize: Int {
        toastQueue.count
    }
    #endif
}

