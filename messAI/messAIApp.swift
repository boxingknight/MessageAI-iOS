//
//  messAIApp.swift
//  messAI
//
//  Created by Isaac Jaramillo on 10/20/25.
//

import SwiftUI
import FirebaseCore
import CoreData

@main
struct messAIApp: App {
    // Initialize Firebase
    init() {
        FirebaseApp.configure()
    }
    
    // Create AuthViewModel
    @StateObject private var authViewModel = AuthViewModel()
    
    // Core Data persistence
    let persistenceController = PersistenceController.shared
    
    // Observe app lifecycle for presence updates
    @Environment(\.scenePhase) var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if authViewModel.isAuthenticated, authViewModel.currentUser != nil {
                    // Main app - Chat List View
                    ContentView()
                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                        .environmentObject(authViewModel)
                } else {
                    // Auth flow
                    AuthenticationView()
                        .environmentObject(authViewModel)
                }
            }
            .overlay(alignment: .top) {
                // Toast notifications overlay
                ToastNotificationView(manager: .shared)
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(newPhase)
        }
    }
    
    /// Handle app lifecycle changes and update presence
    func handleScenePhaseChange(_ phase: ScenePhase) {
        // Only update presence if user is logged in
        guard let userId = authViewModel.currentUser?.id else {
            print("⚠️ No user logged in, skipping presence update")
            return
        }
        
        switch phase {
        case .active:
            // App entered foreground - mark online
            print("🟢 App active - marking user online")
            Task {
                do {
                    try await PresenceService.shared.goOnline(userId)
                } catch {
                    print("❌ Failed to go online: \(error)")
                }
            }
            
        case .inactive:
            // Brief transition (e.g., notification center pulled down)
            // Don't change presence - user might come right back
            print("🟡 App inactive - no presence change")
            break
            
        case .background:
            // App backgrounded - mark offline
            print("🔴 App background - marking user offline")
            Task {
                do {
                    try await PresenceService.shared.goOffline(userId)
                } catch {
                    print("❌ Failed to go offline: \(error)")
                }
            }
            
        @unknown default:
            print("⚠️ Unknown scene phase: \(phase)")
            break
        }
    }
}
