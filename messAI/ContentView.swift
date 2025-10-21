//
//  ContentView.swift
//  messAI
//
//  Created by Isaac Jaramillo on 10/20/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        if authViewModel.isAuthenticated, let currentUser = authViewModel.currentUser {
            // Main app view - Chat List
            ChatListView(
                viewModel: ChatListViewModel(
                    chatService: ChatService(),
                    localDataManager: LocalDataManager.shared,
                    currentUserId: currentUser.id
                )
            )
        } else {
            // Fallback (should never show with proper auth flow)
            VStack {
                Text("Not authenticated")
                    .font(.title)
                Button("Refresh") {
                    // Auth state should update automatically
                }
            }
        }
    }
    
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}
