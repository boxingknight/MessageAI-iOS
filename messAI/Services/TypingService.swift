//
//  TypingService.swift
//  messAI
//
//  Created for PR #12: Presence & Typing Indicators
//

import Foundation
import FirebaseFirestore
import Combine

/// Service for managing typing indicators with debouncing
@MainActor
class TypingService: ObservableObject {
    static let shared = TypingService()
    
    private let db = Firestore.firestore()
    private var typingListeners: [String: ListenerRegistration] = [:]
    private var debounceTimers: [String: Timer] = [:]
    
    @Published var typingUsers: [String: [String]] = [:] // conversationId -> [userIds typing]
    
    private init() {}
    
    // MARK: - Set Typing Status
    
    /// Set user as typing in conversation (debounced)
    /// Automatically stops typing after 3 seconds
    func startTyping(userId: String, conversationId: String) async throws {
        // Cancel existing timer
        debounceTimers[conversationId]?.invalidate()
        
        // Set typing status
        try await setTypingStatus(userId: userId, conversationId: conversationId, isTyping: true)
        
        // Auto-stop after 3 seconds
        let timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                try? await self?.stopTyping(userId: userId, conversationId: conversationId)
            }
        }
        debounceTimers[conversationId] = timer
        
        print("⌨️ User \(userId) started typing in \(conversationId)")
    }
    
    /// Stop typing (immediately)
    func stopTyping(userId: String, conversationId: String) async throws {
        // Cancel timer
        debounceTimers[conversationId]?.invalidate()
        debounceTimers[conversationId] = nil
        
        // Clear typing status
        try await setTypingStatus(userId: userId, conversationId: conversationId, isTyping: false)
        
        print("⌨️ User \(userId) stopped typing in \(conversationId)")
    }
    
    /// Internal: Set typing status in Firestore
    private func setTypingStatus(userId: String, conversationId: String, isTyping: Bool) async throws {
        let typingStatus = TypingStatus(
            userId: userId,
            conversationId: conversationId,
            isTyping: isTyping
        )
        
        try await db.collection("typing")
            .document("\(conversationId)_\(userId)")
            .setData(typingStatus.toDictionary())
    }
    
    // MARK: - Observe Typing
    
    /// Observe typing status for a conversation (real-time)
    func observeTyping(conversationId: String, currentUserId: String) {
        // Don't create duplicate listeners
        guard typingListeners[conversationId] == nil else {
            print("⚠️ Typing listener already exists for \(conversationId)")
            return
        }
        
        print("👀 Starting typing listener for conversation: \(conversationId)")
        
        let listener = db.collection("typing")
            .whereField("conversationId", isEqualTo: conversationId)
            .whereField("isTyping", isEqualTo: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Typing listener error: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("⚠️ No typing data for conversation: \(conversationId)")
                    return
                }
                
                // Extract user IDs of people currently typing (excluding current user)
                let typingUserIds = documents.compactMap { doc -> String? in
                    guard let typingStatus = TypingStatus(dictionary: doc.data()) else {
                        return nil
                    }
                    
                    // Filter out current user and stale statuses
                    guard typingStatus.id != currentUserId, !typingStatus.isStale else {
                        return nil
                    }
                    
                    return typingStatus.id
                }
                
                Task { @MainActor in
                    self.typingUsers[conversationId] = typingUserIds
                    
                    if !typingUserIds.isEmpty {
                        print("⌨️ Users typing in \(conversationId): \(typingUserIds)")
                    }
                }
            }
        
        typingListeners[conversationId] = listener
    }
    
    /// Stop observing typing for a conversation
    func stopObservingTyping(conversationId: String) {
        typingListeners[conversationId]?.remove()
        typingListeners[conversationId] = nil
        typingUsers[conversationId] = nil
        print("🛑 Stopped typing listener for conversation: \(conversationId)")
    }
    
    /// Stop all typing listeners
    func stopAllListeners() {
        print("🛑 Stopping all typing listeners (\(typingListeners.count) active)")
        typingListeners.forEach { $0.value.remove() }
        typingListeners.removeAll()
        typingUsers.removeAll()
        debounceTimers.values.forEach { $0.invalidate() }
        debounceTimers.removeAll()
    }
    
    // MARK: - Helpers
    
    /// Get list of users currently typing in a conversation
    func getUsersTyping(conversationId: String) -> [String] {
        return typingUsers[conversationId] ?? []
    }
    
    /// Check if anyone is typing in a conversation
    func isAnyoneTyping(conversationId: String) -> Bool {
        return !(typingUsers[conversationId] ?? []).isEmpty
    }
}

