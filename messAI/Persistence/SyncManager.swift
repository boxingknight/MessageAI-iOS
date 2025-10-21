//
//  SyncManager.swift
//  messAI
//
//  Created by Isaac Jaramillo on October 20, 2025.
//  Purpose: Manage offline message queue and automatic sync
//

import Foundation
import Combine

class SyncManager: ObservableObject {
    
    // MARK: - Properties
    
    @Published var isSyncing: Bool = false
    @Published var pendingMessageCount: Int = 0
    @Published var lastSyncError: String?
    
    private let localDataManager: LocalDataManager
    private let networkMonitor: NetworkMonitor
    private var cancellables = Set<AnyCancellable>()
    
    // Note: ChatService integration will be added later (PR #5 integration)
    // For now, this is a placeholder structure
    
    // MARK: - Initialization
    
    init(
        localDataManager: LocalDataManager,
        networkMonitor: NetworkMonitor = NetworkMonitor.shared
    ) {
        self.localDataManager = localDataManager
        self.networkMonitor = networkMonitor
        
        setupNetworkObserver()
        updatePendingCount()
    }
    
    // MARK: - Network Observation
    
    private func setupNetworkObserver() {
        networkMonitor.$isConnected
            .dropFirst() // Ignore initial value
            .sink { [weak self] isConnected in
                if isConnected {
                    print("🟢 Network online - triggering sync")
                    Task {
                        await self?.syncPendingMessages()
                    }
                } else {
                    print("🔴 Network offline - pausing sync")
                }
            }
            .store(in: &cancellables)
    }
    
    private func updatePendingCount() {
        do {
            let unsynced = try localDataManager.fetchUnsyncedMessages()
            DispatchQueue.main.async {
                self.pendingMessageCount = unsynced.count
            }
        } catch {
            print("❌ Failed to update pending count: \(error)")
        }
    }
    
    // MARK: - Sync Operations
    
    /// Queues a message for sync
    /// - Parameter message: The message to queue
    func queueMessageForSync(_ message: Message) throws {
        do {
            try localDataManager.saveMessage(message, isSynced: false)
            updatePendingCount()
            
            print("📥 Message queued for sync: \(message.id)")
            
            // If online, sync immediately
            if networkMonitor.isConnected {
                Task {
                    await syncPendingMessages()
                }
            }
        } catch {
            throw error
        }
    }
    
    /// Syncs all pending messages
    func syncPendingMessages() async {
        guard networkMonitor.isConnected else {
            print("⏸️ Sync skipped: No network connection")
            return
        }
        
        guard !isSyncing else {
            print("⏸️ Sync already in progress")
            return
        }
        
        DispatchQueue.main.async {
            self.isSyncing = true
        }
        
        do {
            let unsyncedMessages = try localDataManager.fetchUnsyncedMessages()
            
            print("🔄 Syncing \(unsyncedMessages.count) pending messages...")
            
            for message in unsyncedMessages {
                // TODO: Integrate with ChatService from PR #5
                // For now, simulate sync with delay
                do {
                    try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                    
                    // Mark as synced (temporary - will use ChatService.sendMessage later)
                    try localDataManager.markAsSynced(messageId: message.id)
                    print("✅ Synced message: \(message.id)")
                    
                } catch {
                    // Increment sync attempts on failure
                    try localDataManager.incrementSyncAttempts(
                        messageId: message.id,
                        error: error.localizedDescription
                    )
                    print("❌ Failed to sync message \(message.id): \(error)")
                }
            }
            
            updatePendingCount()
            print("✅ Sync complete!")
            
        } catch {
            print("❌ Sync failed: \(error)")
            DispatchQueue.main.async {
                self.lastSyncError = error.localizedDescription
            }
        }
        
        DispatchQueue.main.async {
            self.isSyncing = false
        }
    }
    
    /// Retries failed messages
    func retryFailedMessages() async {
        do {
            let messages = try localDataManager.fetchUnsyncedMessages()
            
            print("🔄 Retrying \(messages.count) failed messages...")
            
            for message in messages {
                // TODO: Implement with ChatService in PR #5 integration
                try localDataManager.incrementSyncAttempts(
                    messageId: message.id,
                    error: "Retry pending ChatService integration"
                )
            }
            
        } catch {
            print("❌ Retry failed: \(error)")
        }
    }
    
    /// Clears sync errors
    func clearSyncErrors() {
        DispatchQueue.main.async {
            self.lastSyncError = nil
        }
    }
}

