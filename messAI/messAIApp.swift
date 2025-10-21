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
    
    var body: some Scene {
        WindowGroup {
            if authViewModel.isAuthenticated {
                // Main app (placeholder for now)
                ContentView()
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    .environmentObject(authViewModel)
            } else {
                // Auth flow
                AuthenticationView()
                    .environmentObject(authViewModel)
            }
        }
    }
}
