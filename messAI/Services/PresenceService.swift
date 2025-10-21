//
//  PresenceService.swift
//  messAI
//
//  Created for PR #12: Presence & Typing Indicators
//

import Foundation
import FirebaseFirestore
import Combine

/// Service for managing user presence (online/offline status)
@MainActor
class PresenceService: ObservableObject {
    static let shared = PresenceService()
    
    private let db = Firestore.firestore()
    private var presenceListeners: [String: ListenerRegistration] = [:]
    
    @Published var userPresence: [String: Presence] = [:]
    
    private init() {}
    
    // MARK: - Set Presence
    
    /// Set current user as online
    func goOnline(_ userId: String) async throws {
        let presence = Presence(
            userId: userId,
            isOnline: true,
            lastSeen: Date(),
            updatedAt: Date()
        )
        
        try await db.collection("presence").document(userId)
            .setData(presence.toFirestore())
        
        print("✅ Presence: User \(userId) is now online")
    }
    
    /// Set current user as offline
    func goOffline(_ userId: String) async throws {
        try await db.collection("presence").document(userId)
            .updateData([
                "isOnline": false,
                "lastSeen": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ])
        
        print("✅ Presence: User \(userId) is now offline")
    }
    
    // MARK: - Observe Presence
    
    /// Observe presence for a specific user (real-time)
    func observePresence(_ userId: String) {
        // Don't create duplicate listeners
        guard presenceListeners[userId] == nil else {
            print("⚠️ Presence listener already exists for \(userId)")
            return
        }
        
        print("👀 Starting presence listener for user: \(userId)")
        
        let listener = db.collection("presence").document(userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Presence listener error: \(error)")
                    return
                }
                
                guard let data = snapshot?.data() else {
                    print("⚠️ No presence data for user: \(userId)")
                    return
                }
                
                if let presence = Presence.fromFirestore(data, userId: userId) {
                    Task { @MainActor in
                        self.userPresence[userId] = presence
                        print("✅ Updated presence for \(userId): \(presence.presenceText)")
                    }
                }
            }
        
        presenceListeners[userId] = listener
    }
    
    /// Stop observing presence for a user
    func stopObservingPresence(_ userId: String) {
        presenceListeners[userId]?.remove()
        presenceListeners[userId] = nil
        userPresence[userId] = nil
        print("🛑 Stopped presence listener for user: \(userId)")
    }
    
    /// Stop all presence listeners
    func stopAllListeners() {
        print("🛑 Stopping all presence listeners (\(presenceListeners.count) active)")
        presenceListeners.forEach { $0.value.remove() }
        presenceListeners.removeAll()
        userPresence.removeAll()
    }
    
    // MARK: - Fetch Presence (One-Time)
    
    /// Fetch presence for a user (one-time, not real-time)
    func fetchPresence(_ userId: String) async throws -> Presence? {
        let snapshot = try await db.collection("presence")
            .document(userId).getDocument()
        
        guard let data = snapshot.data() else { return nil }
        return Presence.fromFirestore(data, userId: userId)
    }
    
    /// Fetch presence for multiple users (batch)
    func fetchPresence(userIds: [String]) async throws -> [String: Presence] {
        var presenceMap: [String: Presence] = [:]
        
        // Firestore 'in' queries limited to 10 items
        let chunks = userIds.chunked(into: 10)
        
        for chunk in chunks {
            let snapshot = try await db.collection("presence")
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments()
            
            for doc in snapshot.documents {
                if let presence = Presence.fromFirestore(doc.data(), userId: doc.documentID) {
                    presenceMap[doc.documentID] = presence
                }
            }
        }
        
        return presenceMap
    }
}

// MARK: - Array Extension

extension Array {
    /// Chunk array into smaller arrays of specified size
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

