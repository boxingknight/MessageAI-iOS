//
//  messAIApp.swift
//  messAI
//
//  Created by Isaac Jaramillo on 10/20/25.
//

import SwiftUI
import FirebaseCore

@main
struct messAIApp: App {
    // Initialize Firebase
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
